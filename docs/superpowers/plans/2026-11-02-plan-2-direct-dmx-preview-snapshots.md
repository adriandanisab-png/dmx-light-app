# DMX Bridge: Plan 2, Direct DMX, Programmer, Preview, Snapshots

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Mac drives the lights directly through the DSD TECH SH-RS09B (Open DMX). The owner programs looks in a programmer, sees them on a 2D stage preview, saves them as snapshots and plays them back with fades, a grand master and blackout. This is spec milestones 3–5.

**Architecture:** A pure `Engine` (new target `Engine` in `DMXCore`) renders one 512-byte frame from the patch, active snapshot playbacks and the programmer. An `EngineRunner` ticks it at 40 Hz on a dedicated high-priority queue and hands frames to the selected `DMXOutputDevice`. The Open DMX driver runs **its own send loop** (break → MAB → 513 bytes) on its own thread, always sending the latest frame. The preview reads the latest frame on the main thread.

**Tech Stack:** Swift 6, SwiftUI (Canvas for the preview), IOKit (serial port discovery), POSIX termios/ioctl, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-02-dmx-light-app-design.md` (sections 2 goals 3, 4, 7, 8; 4; 6; 7; 8; 9). **Prerequisite:** Plan 1 is merged. Read `docs/console-midi-findings.md` if it has been filled in.

## Global Constraints

- Everything in Plan 1's Global Constraints still applies.
- Engine tick **40 Hz** (`EngineRunner.tickHz`, configurable 25…44).
- Open DMX line: **250000 baud, 8N2**, break **110 µs**, mark-after-break **≥ 12 µs**, payload **start code 0x00 + 512 bytes**, own loop at **30 Hz** default (configurable 20…40). One frame takes ~22.6 ms on the wire, so 40 Hz is the hard ceiling.
- Intensity channels merge **HTP**, all others **LTP**. The programmer overrides everything (LTP, including intensity). Grand master and blackout are applied last.
- For fixture types **without** an `intensity` channel, grand master and blackout scale `red, green, blue, white, amber, uv` instead.
- The preview never runs on the engine or DMX threads. Strobe is drawn at **≤ 10 Hz**.
- Show file additions decode with `decodeIfPresent` and default to empty, so Plan 1 files still open. `formatVersion` stays **1**.
- **One arm switch per window** controls both DMX and MIDI output.

## Review Focus

1. **SH-RS09B unplugged while armed.** Output stops cleanly, a modal alert says "DMX adapter lost: switch the DMX cable to the console", there's no crash or busy loop, and output reconnects when the cable is replugged. Test in Task 5.
2. **Flicker from timing jitter.** UI work (dragging faders, resizing the window, saving) must not delay frames. Test in Task 4 (runner under main-thread load) and Task 10 (real cable).
3. **Grand master at 0 or blackout with RGB-only fixtures.** Lights go fully dark even with no intensity channel. Test in Task 3.
4. **Recalling a snapshot that references a deleted fixture.** That fixture is ignored, and there's no crash. Test in Task 3.
5. **A fade interrupted by another recall** continues from the *current* value, with no jump. Test in Task 3.

---

### Task 1: Attribute helpers, snapshots and stage model

**Files:**
- Create: `Packages/DMXCore/Sources/ShowModel/{FixtureValues,Snapshot,StagePlot,Attributes}.swift`
- Modify: `Packages/DMXCore/Sources/ShowModel/Show.swift` (add `snapshots`, `stage`), `FixtureType.swift` (add `panRangeDegrees: Double?` default 540, `tiltRangeDegrees: Double?` default 270)
- Test: `Packages/DMXCore/Tests/ShowModelTests/{AttributesTests,SnapshotTests}.swift`

**Interfaces:**
- Produces:
  ```swift
  /// channel index (0-based within the fixture) → value
  public typealias FixtureValues = [Int: UInt8]
  public struct RGB: Codable, Hashable, Sendable { public var r, g, b: Double } // 0…1
  public enum Attributes {
    public static func setIntensity(_ v: Double, type: FixtureType, into values: inout FixtureValues)   // v 0…1; no intensity channel → scales colour channels to v
    public static func setColor(_ c: RGB, type: FixtureType, into values: inout FixtureValues)          // white = min(r,g,b) if a white channel exists, subtracted from rgb
    public static func setPanTilt(pan: Double, tilt: Double, type: FixtureType, into values: inout FixtureValues) // 0…1 each; 16-bit split into coarse/fine when fine channels exist
    public static func color(of values: FixtureValues, type: FixtureType) -> RGB }
  public struct Snapshot: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID; public var name: String; public var colorHex: String
    public var values: [UUID: FixtureValues]   // fixture id → channels that are recorded
    public var defaultFade: Double }            // seconds, default 1.0
  public struct StagePlot: Codable, Hashable, Sendable {
    public var widthMeters: Double; public var depthMeters: Double // defaults 10 × 6
    public var backgroundFileName: String? }  // file inside the .dmxshow package
  // Show gains: public var snapshots: [Snapshot]; public var stage: StagePlot
  ```

- [ ] **Step 1: Failing tests:**
  - `intensityOnDimmerChannel`: rgbDimmerStrobe, `setIntensity(0.5)` gives channel 0 = 128 (`UInt8((v*255).rounded())`).
  - `intensityOnRGBOnlyScalesColour`: RGB type with values r=255, g=100, then `setIntensity(0.5)` gives r=128, g=50.
  - `colourWithWhite`: RGBW, `setColor(RGB(1,1,0.5))` gives r=128, g=128, b=0, w=128.
  - `panTilt16bit`: movingHead16, `setPanTilt(pan: 0.5, tilt: 0)` gives pan=128, panFine=0 (0.5×65535 = 32767.5, rounded to 32768).
  - `oldShowFileStillOpens`: Plan 1-style JSON with no `snapshots`/`stage` keys decodes, giving `snapshots == []` and a stage of 10×6.
- [ ] **Step 2:** Run `swift test --package-path Packages/DMXCore --filter "AttributesTests|SnapshotTests"`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests. Expected: pass.
- [ ] **Step 5:** Commit: `feat(model): attributes, snapshots, stage plot`.

---

### Task 2: Programmer state

**Files:**
- Create: `Packages/DMXCore/Sources/ShowModel/Programmer.swift`
- Test: `Packages/DMXCore/Tests/ShowModelTests/ProgrammerTests.swift`

**Interfaces:**
- Consumes: `FixtureValues`, `Attributes`, `Snapshot`.
- Produces:
  ```swift
  public struct Programmer: Equatable, Sendable {
    public var selection: [UUID]                         // ordered, selection order matters for effects later
    public private(set) var values: [UUID: FixtureValues] // only "touched" channels
    public mutating func set(channel: Int, to value: UInt8, for fixtureIDs: [UUID])
    public mutating func apply(_ edit: (FixtureType, inout FixtureValues) -> Void, patch: Patch) // to every selected fixture
    public mutating func clear()
    public func record(name: String, colorHex: String) -> Snapshot }
  ```
- [ ] **Step 1: Failing tests:** `onlyTouchedChannelsRecorded` (setting the colour on 2 fixtures gives a snapshot containing those fixtures and only colour channels); `clearEmpties`; `applyUsesEachFixturesType` (an RGB fixture and an RGBW fixture selected; `setColor` white lands only on the RGBW one).
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests. Expected: pass.
- [ ] **Step 5:** Commit: `feat(model): programmer`.

---

### Task 3: Engine (pure render)

**Files:**
- Create: `Packages/DMXCore/Sources/Engine/{Engine,PlaybackState,ChannelClass}.swift` (new target `Engine` depending on `ShowModel`, `DMXOutput`)
- Test: `Packages/DMXCore/Tests/EngineTests/EngineTests.swift`

**Interfaces:**
- Consumes: `Patch`, `Programmer`, `Snapshot`, `DMXFrame`, `PatchWriter.defaults`.
- Produces:
  ```swift
  public struct PlaybackState: Equatable, Sendable {
    public var snapshotID: UUID
    public var startedAt: TimeInterval; public var fade: Double
    public var fadeFrom: DMXFrame }          // frame on screen when the recall started (Review Focus 5)
  public struct EngineInput: Sendable {
    public var patch: Patch; public var snapshots: [UUID: Snapshot]
    public var playbacks: [PlaybackState]      // activation order, oldest first
    public var programmer: Programmer
    public var grandMaster: Double             // 0…1
    public var blackout: Bool }
  public enum Engine {
    public static func render(_ input: EngineInput, at time: TimeInterval) -> DMXFrame
    public static func isIntensity(_ fn: ChannelFunction, typeHasIntensity: Bool) -> Bool } // intensity, or colour fns when no intensity channel
  ```
  Render order: defaults → each playback (LTP: `lerp(fadeFrom[addr], target, p)`; HTP for intensity: `max(current, lerp(fadeFrom[addr], target, p))`, with `p = clamp((time-startedAt)/fade, 0, 1)` and `fade == 0` meaning p = 1) → programmer values (overwrite) → GM multiplies intensity-class channels → blackout sets them to 0.

- [ ] **Step 1: Failing golden tests** (2 RGB pars at 1 and 4, 1 rgbDimmerStrobe at 7):
  - `defaultsOnly`: an empty input gives frame == `PatchWriter.defaults`.
  - `snapshotFullAfterFade`: snapshot par1 red=255, fade 2, at t = start+2 gives `frame[1] == 255`. At t = start+1 gives 128 (fadeFrom 0).
  - `htpIntensityTwoPlaybacks`: snapshot A dimmer 100, B dimmer 200, both done, gives `frame[7] == 200`. B=50 gives 100.
  - `ltpColourLatestWins`: A red 255, B red 10 (later) gives 10.
  - `programmerOverrides`: playback dimmer 200, programmer dimmer 20, gives 20.
  - `grandMasterRGBOnly` (Review Focus 3): par1 r=200, GM 0.5, gives 100. Blackout gives 0. The dimmer fixture's colour is untouched by GM, but its dimmer channel is scaled.
  - `deletedFixtureIgnored` (Review Focus 4): a snapshot with an unknown fixture UUID renders without crashing, and other values still apply.
  - `interruptedFadeNoJump` (Review Focus 5): fadeFrom = the frame at the interrupt time gives the first frame of the new fade == fadeFrom.
- [ ] **Step 2:** Run `swift test --package-path Packages/DMXCore --filter EngineTests`. Expected: FAIL.
- [ ] **Step 3:** Implement. Add the `Engine` target and `EngineTests` test target to `Package.swift`.
- [ ] **Step 4:** Run the tests. Expected: pass.
- [ ] **Step 5:** Commit: `feat(engine): pure frame renderer with HTP/LTP, fades, GM, blackout`.

---

### Task 4: EngineRunner (timing thread)

**Files:**
- Create: `Packages/DMXCore/Sources/Engine/EngineRunner.swift`
- Test: `Packages/DMXCore/Tests/EngineTests/EngineRunnerTests.swift`

**Interfaces:**
- Consumes: `Engine.render`, `EngineInput`, `DMXOutputDevice`.
- Produces:
  ```swift
  public final class EngineRunner: @unchecked Sendable {
    public init(tickHz: Double = 40, clock: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime })
    public func update(_ mutate: @Sendable (inout EngineInput) -> Void)   // lock-guarded (OSAllocatedUnfairLock)
    public var output: DMXOutputDevice? { get set }                        // nil = preview only
    public var outputEnabled: Bool { get set }                             // the arm switch
    public func latestFrame() -> DMXFrame                                  // for UI/preview
    public func start(); public func stop()
    public var onOutputError: (@Sendable (Error) -> Void)? }
  ```
  Use a `DispatchSourceTimer` on a serial queue with QoS `.userInteractive` and leeway 1 ms. Never touch the main actor from the tick.

- [ ] **Step 1: Failing tests:**
  - `tickRateApprox`: `VirtualDMXOutput`, armed, run 1.0 s, gives 36…44 frames sent.
  - `notArmedSendsNothingButRenders`: `latestFrame()` updates while `sentFrames` stays empty.
  - `mainThreadLoadDoesNotStall` (Review Focus 2): while the test blocks the main thread for 300 ms, the gap between consecutive sent frames is < 60 ms. Record timestamps with a test-only `TimestampingDMXOutput: DMXOutputDevice` (`VirtualDMXOutput` is `final`).
  - `outputErrorReported`: a device that throws calls `onOutputError` once, and the runner keeps rendering.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests. Expected: pass (run 3× to check for flakiness).
- [ ] **Step 5:** Commit: `feat(engine): real-time engine runner`.

---

### Task 5: Open DMX driver for the SH-RS09B

**Files:**
- Create: `Packages/DMXCore/Sources/DMXOutput/{SerialLink,POSIXSerialLink,SerialPortDiscovery,OpenDMXOutput}.swift`
- Test: `Packages/DMXCore/Tests/DMXOutputTests/OpenDMXOutputTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public protocol SerialLink: AnyObject, Sendable {
    func open(path: String, baud: Int, stopBits: Int) throws
    func sendBreak(microseconds: Int) throws   // TIOCSBRK, sleep, TIOCCBRK
    func sleep(microseconds: Int)
    func write(_ bytes: [UInt8]) throws
    func drain() throws                        // tcdrain
    func close() }
  public final class POSIXSerialLink: SerialLink   // open(O_RDWR|O_NOCTTY|O_NONBLOCK) then clear O_NONBLOCK; cfmakeraw; CSTOPB; CLOCAL|CREAD; IOSSIOSPEED 250000
  public struct SerialPortInfo: Hashable, Sendable { public let path: String; public let vendorID: Int?; public let productName: String? }
  public enum SerialPortDiscovery { public static func ports() -> [SerialPortInfo]; public static let ftdiVendorID = 0x0403 } // IOKit kIOSerialBSDServiceValue, callout device /dev/cu.*
  public enum DMXDeviceError: Error, Equatable { case openFailed(String), writeFailed(String), disconnected }
  public final class OpenDMXOutput: DMXOutputDevice {
    public init(path: String, link: SerialLink = POSIXSerialLink(), refreshHz: Double = 30)
    public func start() throws; public func stop()
    public var onDisconnect: (@Sendable () -> Void)?
    // send(_:) only stores the latest frame; the internal thread transmits it
  }
  ```
  Each loop iteration: `sendBreak(110)` → `sleep(12)` → `write([0x00] + frame.bytes)` → `drain()` → sleep until the next period. On a write error, set `isConnected = false`, call `onDisconnect` once, close the link, and retry `open` every 1 s until it succeeds (Review Focus 1).

- [ ] **Step 1: Failing tests** with `FakeSerialLink` (records calls):
  - `openUsesDMXLineSettings`: `open(path:"/dev/cu.usbserial-X", baud: 250000, stopBits: 2)`.
  - `frameSequence`: after `send(frame)` with `frame[1]=255` and ~100 ms of running, the first recorded calls are `[.break(110), .sleep(12), .write(513 bytes starting [0x00, 0xFF]), .drain]`, repeating.
  - `refreshRateApprox`: 30 Hz for 1 s gives 27…33 writes.
  - `writeErrorDisconnectsAndRetries` (Review Focus 1): the fake throws on the 3rd write, giving `onDisconnect` called once, `isConnected == false`, and `open` called again within 1.5 s. Once the fake stops throwing, `isConnected == true`.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement. Use a dedicated `Thread` with `qualityOfService = .userInteractive`. `POSIXSerialLink` and `SerialPortDiscovery` aren't unit-tested. Add a `#if DEBUG` command-line harness target `opendmx-probe` (`Packages/DMXCore/Sources/OpenDMXProbe/main.swift`) that lists ports and sends a chase on channel 1 for hardware checks.
- [ ] **Step 4:** Run the tests. Expected: pass.
- [ ] **Step 5:** Commit: `feat(output): Open DMX (FTDI) driver for SH-RS09B`.

---

### Task 6: Fixture look derivation (for the preview)

**Files:**
- Create: `Packages/DMXCore/Sources/Engine/FixtureLook.swift`
- Test: `Packages/DMXCore/Tests/EngineTests/FixtureLookTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct FixtureLook: Equatable, Sendable {
    public var color: RGB; public var intensity: Double          // 0…1
    public var strobeHz: Double?                                 // nil = no strobe
    public var panDegrees: Double?; public var tiltDegrees: Double? }
  public extension FixtureLook {
    static func from(frame: DMXFrame, fixture: Fixture, type: FixtureType) -> FixtureLook }
  ```
  Rules: intensity = the intensity channel/255, or 1 if there's none. Colour from r/g/b plus white added to each (clamped); no colour channels gives white. Strobe: 0…9 = nil, 10…255 maps linearly to 1…20 Hz (generic guess, documented in code). Pan = (value16/65535 − 0.5) × panRange; tilt likewise.

- [ ] **Step 1: Failing tests:** `rgbParRed`; `dimmerOnlyIsWhite`; `strobeMapping` (10 → 1 Hz, 255 → 20 Hz, 5 → nil); `panCentre` (pan 128/fine 0 on a 540° head gives ≈ 0.0°, within ±1.1).
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests. Expected: pass.
- [ ] **Step 5:** Commit: `feat(engine): fixture look derivation for preview`.

---

### Task 7: Stage preview and stage editor UI

**Files:**
- Create: `App/Stage/{StageView,StageFixtureGlyph,StageEditorToolbar,StagePreviewModel}.swift`
- Modify: `App/AppModel.swift` (own `EngineRunner`, start it on window open, and replace the Plan 1 direct `gate.submit` path with `runner.update`)
- Modify: `App/ShowDocument.swift` (read/write the background image file in the package)
- Test: `UITests/StageUITests.swift`

**Interfaces:**
- Consumes: `EngineRunner.latestFrame()`, `FixtureLook.from`, `StagePlot`, `Fixture.stagePosition`.
- Produces: `StageView(document:selection:)`, used as the "Stage" tab and embedded beside the Programmer.

Requirements (spec 6): SwiftUI `Canvas` inside a `TimelineView(.animation)`. Each fixture is a glowing radial-gradient disc (radius ∝ intensity, colour = look colour). Moving heads get a beam line with direction = pan and length = tilt. Strobe toggles visibility at `min(strobeHz, 10)`. Fixtures with no position are lined up along the bottom edge. Drag moves a fixture (writes `stagePosition`), click selects, shift-click adds, and a lasso multi-selects. "Set background…" imports a JPEG/PNG into the package. A "Channels" sub-tab shows the Plan 1 `ChannelMonitorView` fed by `latestFrame()`.

- [ ] **Step 1: Failing UI test** `testDragFixtureUpdatesPosition`: add 1 RGB fixture, drag `stageFixture.<id>` by (+100, 0), and its accessibility value `x=` increases.
- [ ] **Step 2:** Run `xcodebuild test -scheme DMXBridge -destination 'platform=macOS' -only-testing:DMXBridgeUITests/StageUITests`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the test. Expected: PASS. Manually: 50 fixtures with a rainbow typed into the programmer stay smooth (no visible hitching).
- [ ] **Step 5:** Commit: `feat(ui): 2D stage preview and editor`.

---

### Task 8: Programmer UI

**Files:**
- Create: `App/Programmer/{ProgrammerView,IntensityControl,ColorControl,PanTiltPad,StrobeControl,RawChannelFaders,RecordSnapshotSheet}.swift`
- Test: `UITests/ProgrammerUITests.swift`

**Interfaces:**
- Consumes: `Programmer`, `Attributes`, `EngineRunner.update`, `Programmer.record`.
- Produces: `ProgrammerView(document:)` as the "Programmer" tab (stage on the left, controls on the right).

Requirements (spec goal 3): the selection comes from the stage or a fixture list. Controls: intensity fader, colour picker (SwiftUI `ColorPicker` plus 12 quick swatches), pan/tilt XY pad (only when a selected type has pan/tilt), strobe fader, raw faders for every channel of the first selected type. **Esc** clears the programmer. "Record…" asks for a name and colour and adds to `show.snapshots`. A banner "Programmer active: overrides playback" shows while it's non-empty.

- [ ] **Step 1: Failing UI test** `testRecordSnapshot`: add 2 RGB fixtures, select all, pick the red swatch, Record "Red wash", and the Library has 1 snapshot named "Red wash".
- [ ] **Step 2:** Run the test. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the test. Expected: PASS.
- [ ] **Step 5:** Commit: `feat(ui): programmer`.

---

### Task 9: Playback page, devices and arming

**Files:**
- Create: `App/Playback/{PlaybackView,PlaybackButton,GrandMasterFader,BlackoutButton}.swift`, `App/Devices/{DevicesView,OutputMode}.swift`
- Modify: `App/AppModel.swift` (`outputMode`, a single `isArmed` driving both `runner.outputEnabled` and `console.isArmed`, adapter-lost alert)
- Test: `UITests/PlaybackUITests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum OutputMode: String, Codable, CaseIterable { case previewOnly, directOpenDMX, consoleMIDI } // stored per Mac in UserDefaults, not in the show
  // AppModel: func recall(_ snapshotID: UUID, layered: Bool, fade: Double?)   // not layered = replaces all playbacks
  //           func release(_ snapshotID: UUID); var grandMaster: Double; var blackout: Bool
  ```
Requirements: a page of big buttons (4×4, multiple pages) holding snapshots and, in Console mode, the Plan 1 console cells and looks. Click = exclusive recall with the snapshot's fade, **shift-click** = layer/unlayer. A lit state shows active buttons. Grand master fader. Huge **BLACKOUT** (key **B**). Number keys 1–9 fire buttons on the current page. Devices view: mode picker; Direct shows `SerialPortDiscovery.ports()` (FTDI first) and a refresh-rate stepper; Console shows Plan 1's MIDI settings. The toolbar **ARM** button and a status line ("Direct · /dev/cu.usbserial-A10K · 30 Hz" / "Adapter lost"). On `onDisconnect`, show a modal alert: "DMX adapter lost: switch the DMX cable to the console".

- [ ] **Step 1: Failing UI test** `testRecallLightsButtonAndBlackoutKey`: with a snapshot present, click its button and it shows `on`. Press B and the blackout button shows `on`. In preview-only mode, `latestFrame` is all-zero intensity (read via a debug accessibility label on the status bar `frameSum=0`).
- [ ] **Step 2:** Run the test. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run all tests: `swift test --package-path Packages/DMXCore && xcodebuild test -scheme DMXBridge -destination 'platform=macOS'`. Expected: all pass.
- [ ] **Step 5:** Commit: `feat(ui): playback page, devices and unified arming`.

---

### Task 10: Hardware test part 2

**Files:**
- Modify: `docs/hardware-test.md`

- [ ] **Step 1:** Add part 2, the owner's checklist:
  1. Plug in the SH-RS09B and connect DMX to the first fixture.
  2. Devices → Direct → pick the port → ARM.
  3. Configure the real fixtures in Config.
  4. Touch each channel and confirm the light responds.
  5. **Flicker check:** hold one static look for 5 minutes while dragging windows and saving. Note any flicker. If there is any, try refresh 25 Hz and 40 Hz, and record the best value.
  6. Unplug the adapter while armed and check the alert. Replug and check output resumes.
  7. **Backup drill:** move the DMX cable to the console and fire a console scene from the Mac.
- [ ] **Step 2:** Commit: `docs: hardware test part 2 (direct DMX and backup drill)`.

**Done for plan 2:** the owner can program, preview, save and play back looks on real lights through the SH-RS09B, with blackout, grand master and an adapter-lost alert.
