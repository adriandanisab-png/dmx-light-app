# DMX Bridge: Plan 4, Extras and Hardening

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish v1: a printable console cheat sheet for the backup, QLC+ fixture import, Enttec USB Pro support with console scene capture, then hardening, packaging and full hardware acceptance. This is spec milestones 8–9. **The cut order if time runs short** (spec section 14): capture (Tasks 3–4), then QLC+ import (Task 2), then the cheat sheet (Task 1), then the Enttec driver (Task 3). Tasks 5–6 are never cut.

**Architecture:** The new pure pieces (`CheatSheet`, `QXFImporter`, `EnttecProCodec`) live in `DMXCore` and are fully unit-tested. The Enttec Pro driver reuses `SerialLink` from Plan 2. The UI adds export/import sheets and a capture wizard.

**Tech Stack:** Swift 6, SwiftUI, Foundation `XMLParser`, SwiftUI `ImageRenderer` → PDF, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-02-dmx-light-app-design.md` (goals 2, 10, 11, 13; sections 4, 7, 10). **Prerequisite:** Plans 1–3 merged.

## Global Constraints

- Everything in Plans 1–3 Global Constraints applies.
- Console layout: scanner *n* = DMX **16(n−1)+1 … 16n**. The console's 8 faders show **Page A = channels 1–8** and **Page B = channels 9–16** of the selected scanner (this is the "A/B" the owner described).
- Enttec USB Pro framing: `0x7E, label, lenLSB, lenMSB, data…, 0xE7`. Labels: **6** send DMX (data = `0x00` + 512), **8** receive-on-change mode (data `0x00` = always send), **5** received DMX (data = status byte, start code, channels).
- QLC+ fixture files are Apache-2.0. Committed test files keep their license header.
- No network access at runtime. Import only from files the user picks.

## Review Focus

1. **Fixtures not reachable by the console** (address not at a 16-channel scanner boundary, more than 16 channels, address > 192): the cheat sheet lists them under "Not on console", and they're never silently dropped. Test in Task 1.
2. **Malformed or unsupported `.qxf` files** (missing Mode, a channel referenced by a mode but not defined): import shows a clear error, nothing half-imported. Test in Task 2.
3. **Enttec input noise / partial packets** (bytes split across reads, a junk byte before `0x7E`): the decoder resyncs and never crashes. Test in Task 3.
4. **Capture while the console has a fade time set:** the wizard waits for two identical frames before storing, with a 10 s timeout and "unstable" status. Test in Task 4.
5. **App quit or crash during autosave:** the previous version of the show is intact. Test in Task 5.

---

### Task 1: Console cheat sheet

**Files:**
- Create: `Packages/DMXCore/Sources/Engine/CheatSheet.swift`, `App/Export/{CheatSheetView,CheatSheetExporter}.swift`
- Test: `Packages/DMXCore/Tests/EngineTests/CheatSheetTests.swift`

**Interfaces:**
- Consumes: `Engine.render` (a snapshot rendered alone, GM 1, no programmer), `Patch`.
- Produces:
  ```swift
  public struct CheatSheetScanner: Equatable, Sendable {
    public var scanner: Int                                 // 1…12
    public var fixtureName: String?
    public var pageA: [UInt8]; public var pageB: [UInt8] }  // 8 values each
  public struct CheatSheetPage: Equatable, Sendable {
    public var snapshotName: String; public var suggestedBank: Int?; public var suggestedScene: Int?
    public var scanners: [CheatSheetScanner]               // only scanners with any non-zero value
    public var notOnConsole: [String] }                     // fixture names, Review Focus 1
  public enum CheatSheet {
    public static func page(for snapshot: Snapshot, show: Show) -> CheatSheetPage }
  ```
  A fixture is on the console when `consoleScanner` is set, its `address == 16(scanner−1)+1` and its `channelCount ≤ 16`. Otherwise it goes in `notOnConsole`. Values come from the rendered frame at addresses 16(n−1)+1…16n.
- [ ] **Step 1: Failing tests:** `scannerValuesSplitAB` (a par on scanner 2 at address 17 with red=255 on ch 2 gives `pageA[1] == 255`); `misalignedListedNotOnConsole` (a fixture at address 20 with scanner 2 lands in `notOnConsole`); `wideFixtureNotOnConsole` (20 ch); `emptyScannersOmitted`.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement `CheatSheet`. In the app, use Library → select snapshots → "Export console cheat sheet…" to render a `CheatSheetView` per page. Each page has a header (snapshot name, a "Program into Bank __ Scene __" box), a table of scanners × Page A/B faders showing the value and %, and a footer listing the not-on-console fixtures. Use `ImageRenderer` to write a multi-page PDF, A4 portrait, and offer Save / Print.
- [ ] **Step 4:** Run the tests. Expected: pass. Manually export 2 snapshots and check the PDF.
- [ ] **Step 5:** Commit: `feat: console cheat sheet export`.

---

### Task 2: QLC+ `.qxf` fixture import

**Files:**
- Create: `Packages/DMXCore/Sources/ShowModel/QXFImporter.swift`, `App/Config/ImportQXFSheet.swift`
- Create test fixtures: `Packages/DMXCore/Tests/ShowModelTests/Resources/{generic-rgb.qxf,generic-moving-head.qxf,broken-mode.qxf}`. Take the first two from the QLC+ repository (`resources/fixtures/`, Apache-2.0, keep headers). Hand-write `broken-mode.qxf` with a mode referencing an undefined channel.
- Test: `Packages/DMXCore/Tests/ShowModelTests/QXFImporterTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct QXFDefinition: Sendable { public var manufacturer: String; public var model: String; public var modes: [String] }
  public enum QXFError: Error, Equatable { case notQXF, noModes, undefinedChannel(String), modeNotFound(String) }
  public enum QXFImporter {
    public static func read(_ data: Data) throws -> QXFDefinition
    public static func fixtureType(from data: Data, mode: String) throws -> FixtureType }
  ```
  Mapping `<Channel Preset="…">` → `ChannelFunction`: `IntensityMasterDimmer|IntensityDimmer`→intensity, `IntensityRed`→red, `IntensityGreen`→green, `IntensityBlue`→blue, `IntensityWhite`→white, `IntensityAmber`→amber, `IntensityUV`→uv, `PositionPan`→pan, `PositionPanFine`→panFine, `PositionTilt`→tilt, `PositionTiltFine`→tiltFine, `ShutterStrobeSlowFast|ShutterStrobeFastSlow`→strobe, `ColorWheel|ColorMacro`→colorWheel, `GoboWheel`→gobo, `SpeedPanTiltSlowFast|SpeedPanTiltFastSlow`→speed. Older files use `<Group>`: `Intensity` with `<Colour>` Red/Green/… maps to the matching colour, otherwise intensity; `Pan`/`Tilt` (`Byte="1"` = fine); `Colour`→colorWheel; `Gobo`→gobo; `Shutter`→strobe; `Speed`→speed. Anything else → generic. `<Capability Min Max>text` → `ValueRange`. Type name = "Manufacturer Model (Mode)".
- [ ] **Step 1: Failing tests:** `readsModes`; `rgbMapsFunctions` (generic RGB gives `[red, green, blue]`); `movingHeadFine` (has panFine and tiltFine); `capabilitiesBecomeRanges`; `brokenModeThrows` (Review Focus 2: throws `.undefinedChannel`); `garbageThrowsNotQXF`.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement with `XMLParser` (no third-party XML library). In the Config panel, add an "Import QLC+ fixture…" button with a file picker, a mode picker and a preview of the channel list before adding.
- [ ] **Step 4:** Run the tests. Expected: pass.
- [ ] **Step 5:** Commit: `feat: QLC+ fixture import`.

---

### Task 3: Enttec USB Pro codec, output and input

**Files:**
- Create: `Packages/DMXCore/Sources/DMXOutput/{EnttecProCodec,EnttecProOutput,EnttecProInput}.swift`
- Modify: `App/Devices/{DevicesView,OutputMode}.swift` (add `case directEnttecPro`)
- Test: `Packages/DMXCore/Tests/DMXOutputTests/EnttecProCodecTests.swift`

**Interfaces:**
- Consumes: `SerialLink`, `SerialPortDiscovery`.
- Produces:
  ```swift
  public enum EnttecProCodec {
    public static func sendDMX(_ frame: DMXFrame) -> [UInt8]   // label 6
    public static func receiveAlways() -> [UInt8]               // label 8, data [0x00]
    public struct Decoder { public init(); public mutating func feed(_ bytes: [UInt8]) -> [(label: UInt8, data: [UInt8])] } }
  public final class EnttecProOutput: DMXOutputDevice { public init(path: String, link: SerialLink = POSIXSerialLink()) } // send writes one label-6 packet; no break needed
  public final class EnttecProInput: Sendable {
    public init(path: String, link: SerialLink = POSIXSerialLink())
    public var onFrame: (@Sendable (DMXFrame) -> Void)? }       // from label 5, status byte 0 only
  ```
  `SerialLink` gains `func read(max: Int, timeoutMs: Int) throws -> [UInt8]` (add it to `POSIXSerialLink` and the fake).
- [ ] **Step 1: Failing tests:** `sendDMXFraming` (513 data bytes gives header `[0x7E, 6, 0x01, 0x02]` and trailer `0xE7`); `receiveAlwaysBytes == [0x7E, 8, 1, 0, 0, 0xE7]`; `decoderSplitPackets` (one packet fed in 3 chunks gives 1 message); `decoderResyncsOnJunk` (Review Focus 3: `[0x00, 0x13] + packet` gives 1 message); `label5ToFrame` (status 0, start 0, ch1 = 200 gives `frame[1] == 200`).
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement. In Devices, `directEnttecPro` lists FTDI ports the same way as Open DMX. The user picks which kind they have, because both use FTDI chips.
- [ ] **Step 4:** Run the tests. Expected: pass.
- [ ] **Step 5:** Commit: `feat(output): Enttec USB Pro output and input`.

---

### Task 4: Console scene capture wizard

**Files:**
- Create: `Packages/DMXCore/Sources/ConsoleMIDI/CaptureSession.swift`, `App/Console/CaptureWizard.swift`
- Modify: `ConsoleMap.swift` (`ConsoleCell.capturedFrame: [UInt8]?`, decodeIfPresent), `App/Stage/StagePreviewModel.swift` (Console mode uses captured frames for the preview), Library ("Convert captured scene to snapshot")
- Test: `Packages/DMXCore/Tests/ConsoleMIDITests/CaptureSessionTests.swift`

**Interfaces:**
- Consumes: `ConsoleController`, `EnttecProInput` (abstracted as a frame source), `ConsoleState`.
- Package change: the `ConsoleMIDI` target gains a dependency on `DMXOutput` (for `DMXFrame`).
- Produces:
  ```swift
  public enum CaptureResult: Equatable, Sendable { case captured(DMXFrame), unstable, failed(String) }
  @MainActor public final class CaptureSession {
    public init(controller: ConsoleController, frames: AsyncStream<DMXFrame>, settleTimeout: Duration = .seconds(10))
    public func capture(_ targets: [ConsoleTarget]) async -> [ConsoleTarget: CaptureResult] } // scenes only; chases rejected
  ```
  For each target: make sure all cells are believed off (`recall` an empty look), fire the target, wait for **two consecutive identical frames ≥ 200 ms apart** (Review Focus 4), store the frame, then toggle the target off. A timeout gives `.unstable`.
- [ ] **Step 1: Failing tests** with a scripted frame stream and `RecordingMIDISender`: `capturesStableFrame`; `fadingFramesWaitUntilStable`; `neverStableGivesUnstable` (timeout 1 s in the test); `sceneTurnedOffAfterCapture` (sent notes: on, then off); `chaseRejected`.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement. The wizard UI shows wiring instructions (console DMX OUT → Enttec Pro DMX IN; "set console fade time to 0 for faster capture"), lets the user pick banks/scenes, shows a progress list with per-scene status, and offers "Convert to snapshots". In Console mode, the preview uses `capturedFrame` where present.
- [ ] **Step 4:** Run the tests. Expected: pass.
- [ ] **Step 5:** Commit: `feat(console): scene capture wizard`.

---

### Task 5: Hardening

**Files:**
- Modify: as needed across `App/` and `DMXCore`
- Create: `Packages/DMXCore/Tests/ShowModelTests/ShowFuzzTests.swift`, `Packages/DMXCore/Tests/EngineTests/EnginePerformanceTests.swift`, `UITests/AutosaveUITests.swift`

- [ ] **Step 1: Failing/benchmark tests:**
  - `randomJSONNeverCrashes`: 500 random mutations of a valid show JSON. `Show.decode` either succeeds or throws and never traps.
  - `render50FixturesUnder2ms`: `Engine.render` with 50 moving heads, 10 playbacks and 4 effects, measured over 1000 runs, averages < 2 ms (Release).
  - `testAutosaveSurvivesKill` (Review Focus 5): edit, wait for autosave, `app.terminate()`, relaunch, reopen, and the edit is present. Then corrupt-write simulation: the package's `show.json` replaced mid-write leaves the previous version opening (rely on `FileWrapper` atomic writes, and assert it).
- [ ] **Step 2:** Run the tests. Fix any failure.
- [ ] **Step 3:** Audit and fix:
  - Device hot-plug for the MIDI interface (CoreMIDI notify block refreshes destinations; reselect by uniqueID) and for the serial adapter.
  - Every error path shows a toast or alert with plain text.
  - Arming is off after every launch.
  - Dark theme contrast.
  - Playback buttons at least 64×64 pt.
- [ ] **Step 4:** Run all tests: `swift test --package-path Packages/DMXCore && xcodebuild test -scheme DMXBridge -destination 'platform=macOS'`. Expected: all pass.
- [ ] **Step 5:** Commit: `chore: hardening, fuzz and performance tests`.

---

### Task 6: Packaging and acceptance

**Files:**
- Create: `scripts/build-release.sh`, `docs/user-guide.md`
- Modify: `README.md`, `docs/hardware-test.md`

- [ ] **Step 1:** `scripts/build-release.sh`: `xcodegen generate`, `xcodebuild -scheme DMXBridge -configuration Release archive`, export with ad-hoc signing (`CODE_SIGN_IDENTITY=-`), zip `DMXBridge.app` to `dist/DMXBridge-<version>.zip`. README note: the first launch needs right-click → Open (not notarised).
- [ ] **Step 2:** Run `scripts/build-release.sh`. Expected: `dist/DMXBridge-*.zip` exists and the app launches.
- [ ] **Step 3:** Write `docs/user-guide.md` for the owner, in plain language with screenshots:
  1. Wiring: the MIDI cable's OUT plug into the console; the SH-RS09B into the fixtures.
  2. Setting the console MIDI channel.
  3. Configuring fixtures.
  4. Programming snapshots.
  5. Effects.
  6. Cue lists and console backup parts.
  7. Show day checklist.
  8. **What to do if something fails** (cable swap, switch the mode to Console, GO).
- [ ] **Step 4:** Add part 4 (full acceptance) to `docs/hardware-test.md`. It runs parts 1–3 again on the release build, plus a 60-minute soak test with a cue list on auto-follow. The owner signs off.
- [ ] **Step 5:** Commit: `docs: user guide, release script, acceptance checklist`.

**Done for plan 4 = v1 done.** Next (v1.1, separate spec): drive the app from an external MIDI controller with "MIDI learn" on every playback action, plus Art-Net output and a 3D preview.
