# DMX Bridge: Plan 1, Foundation + Console Mode

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Mac app where the owner defines fixtures and channels in a config panel and fires the Stairville DMX Master II's stored scenes, chases and blackout over MIDI. This is spec milestones 1–2, usable with only a USB-MIDI cable.

**Architecture:** Core logic lives in a local Swift package `DMXCore` (targets `ShowModel`, `DMXOutput`, `ConsoleMIDI`), fully unit-tested with `swift test` and no hardware. A thin SwiftUI document app `DMXBridge`, generated with XcodeGen, holds the UI. CoreMIDI sits behind a `MIDISender` protocol so tests use a recording fake.

**Tech Stack:** Swift 6, SwiftUI, CoreMIDI, Swift Testing (`import Testing`), XcodeGen, macOS 14+.

**Spec:** `docs/superpowers/specs/2026-11-02-dmx-light-app-design.md`. Read sections 1, 2 (goals 1, 2, 9, 12, 13), 4, 5, 8, 9 and 10 before starting.

**Later plans** (in `docs/superpowers/plans/`, run in order):
- Plan 2: Engine + programmer + 2D stage preview + snapshots/fades + playback page + **Open DMX (SH-RS09B) driver** (spec milestones 3–5).
- Plan 3: Effects, tap tempo, cue lists with two-part cues (milestones 6–7).
- Plan 4: Capture wizard, cheat sheet, QLC+ import, Enttec Pro, hardening (milestones 8–9).

## Global Constraints

- macOS deployment target **14.0**. Swift language mode 6. Universal build (arm64 + x86_64).
- One DMX universe: addresses **1…512**.
- Console: DMX Master II, scanners **1…12**, 16 channels each. MIDI reaches **banks 1…15** only, scenes **1…8**, chases **1…6**.
- Note map (spec 5.1): scene(bank b, scene s) = `(b-1)*8 + (s-1)`; chase c = `119 + c`; blackout = `126`.
- Note On velocity **127**. **Never send velocity 0.** Default Note Off **50 ms** after each Note On (configurable to off).
- MIDI channel setting **1…16** (wire value 0…15).
- No light/MIDI output until the user **arms output** (spec section 4). Opening a show never sends anything.
- No third-party runtime dependencies in plan 1.
- Show file: document package `.dmxshow` holding `show.json`, `formatVersion = 1`.
- Dark UI, large hit targets on playback buttons. Keyboard **B** = blackout.

## Review Focus

1. **Editing a fixture type after patching** (adding channels) can push fixtures into overlap or past 512. The patch must revalidate and show the issue, never silently clip. Test in Task 2.
2. **USB-MIDI cable unplugged mid-show.** Firing a scene must fail visibly, and the believed console state must **not** change. Test in Task 6.
3. **Corrupt or newer-version show file.** Opening shows an error, no crash, and nothing is sent. Test in Task 7.
4. **Bank 16–30 or out-of-range targets** typed into the console map must be rejected before any MIDI is sent. Test in Task 4.
5. **Firing while not armed** sends nothing, and the UI explains why. Test in Task 6.

---

### Task 1: Repository scaffold

**Files:**
- Create: `Packages/DMXCore/Package.swift`, `Packages/DMXCore/Sources/{ShowModel,DMXOutput,ConsoleMIDI}/Placeholder.swift`, `Packages/DMXCore/Tests/{ShowModelTests,DMXOutputTests,ConsoleMIDITests}/SmokeTests.swift`
- Create: `project.yml` (XcodeGen), `App/DMXBridgeApp.swift`, `App/Info.plist`, `.gitignore` (ignore `*.xcodeproj`, `.build`, `DerivedData`)
- Create: `README.md` (how to build: `brew install xcodegen && xcodegen generate && open DMXBridge.xcodeproj`)

**Interfaces:**
- Produces: package products `ShowModel`, `DMXOutput` (depends on ShowModel), `ConsoleMIDI` (depends on ShowModel). App target `DMXBridge` links all three. Scheme `DMXBridge`.

- [ ] **Step 1:** Write `Package.swift` (swift-tools-version 6.0, `.macOS(.v14)`) and one `@Test func smoke() { #expect(true) }` per test target.
- [ ] **Step 2:** Run `swift test --package-path Packages/DMXCore`. Expected: 3 tests pass.
- [ ] **Step 3:** Write `project.yml`: app target `DMXBridge`, bundle id `app.dmxbridge.DMXBridge`, deployment target 14.0, local package dependency `Packages/DMXCore`, document type `.dmxshow` (UTI `app.dmxbridge.show`, conforms to `com.apple.package`), `NSAppleEventsUsageDescription` not needed. `DMXBridgeApp` shows an empty `WindowGroup`.
- [ ] **Step 4:** Run `xcodegen generate && xcodebuild -scheme DMXBridge -destination 'platform=macOS' build`. Expected: `** BUILD SUCCEEDED **`.
- [ ] **Step 5:** Commit: `chore: scaffold DMXCore package and DMXBridge app`.

---

### Task 2: Show model: fixture types, fixtures, patch validation

**Files:**
- Create: `Packages/DMXCore/Sources/ShowModel/{ChannelFunction,FixtureType,Fixture,Patch}.swift`
- Test: `Packages/DMXCore/Tests/ShowModelTests/PatchTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum ChannelFunction: String, Codable, CaseIterable, Sendable {
    case intensity, red, green, blue, white, amber, uv, colorWheel, gobo,
         pan, panFine, tilt, tiltFine, strobe, speed, macro, generic }
  public struct ValueRange: Codable, Hashable, Sendable { public var from: UInt8; public var to: UInt8; public var label: String }
  public struct ChannelDef: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID; public var name: String; public var function: ChannelFunction
    public var defaultValue: UInt8; public var ranges: [ValueRange] }
  public struct FixtureType: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID; public var name: String; public var channels: [ChannelDef]
    public var channelCount: Int { channels.count } }
  public struct StagePoint: Codable, Hashable, Sendable { public var x: Double; public var y: Double } // 0…1 of stage
  public struct Fixture: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID; public var name: String; public var typeID: UUID
    public var address: Int            // 1…512, first channel
    public var consoleScanner: Int?    // 1…12
    public var stagePosition: StagePoint? }
  public enum PatchIssue: Equatable, Sendable {
    case overlap(UUID, UUID), pastEnd(UUID), addressOutOfRange(UUID), unknownType(UUID),
         scannerOutOfRange(UUID), duplicateScanner(Int), emptyType(UUID) }
  public struct Patch: Codable, Equatable, Sendable {
    public var types: [FixtureType]; public var fixtures: [Fixture]
    public func type(of fixture: Fixture) -> FixtureType?
    public func validate() -> [PatchIssue]
    public func nextFreeAddress(channelCount: Int) -> Int?
    public mutating func addFixtures(typeID: UUID, count: Int, startAddress: Int?, namePrefix: String) throws -> [Fixture] }
  public enum PatchError: Error, Equatable { case unknownType, noRoom, invalidCount }
  ```

- [ ] **Step 1: Write failing tests** in `PatchTests.swift`:
  - `addFixturesAutoAddresses`: an RGB type (3 ch), `addFixtures(count: 4, startAddress: nil, namePrefix: "Par")` gives addresses `[1, 4, 7, 10]` and names `["Par 1", "Par 2", "Par 3", "Par 4"]`.
  - `overlapDetected`: fixtures at 1 (3 ch) and 3 (3 ch) give `validate() == [.overlap(a.id, b.id)]`.
  - `pastEndDetected`: a 16-ch fixture at 500 gives `.pastEnd`.
  - `growingTypeRevalidates` (Review Focus 1): two 3-ch fixtures at 1 and 4, valid. Append one channel to the type, and `validate()` contains `.overlap`.
  - `duplicateScanner`: two fixtures with `consoleScanner: 3` give `.duplicateScanner(3)`. A scanner of 13 gives `.scannerOutOfRange`.
  - `noRoomThrows`: 512-ch type, adding 2 fixtures throws `PatchError.noRoom`.
  - `codableRoundTrip`: encode then decode gives an equal `Patch`.
- [ ] **Step 2:** Run `swift test --package-path Packages/DMXCore --filter PatchTests`. Expected: FAIL (types undefined).
- [ ] **Step 3:** Implement. `validate()` reports each overlapping pair once (lower address first) and returns issues sorted for stable output. `nextFreeAddress` returns the lowest gap that fits.
- [ ] **Step 4:** Run the tests again. Expected: all pass.
- [ ] **Step 5:** Commit: `feat(model): fixture types, fixtures and patch validation`.

---

### Task 3: Built-in templates, DMX frame, patch writer, virtual output, arming

**Files:**
- Create: `Packages/DMXCore/Sources/ShowModel/BuiltInTemplates.swift`
- Create: `Packages/DMXCore/Sources/DMXOutput/{DMXFrame,PatchWriter,DMXOutput,VirtualDMXOutput,OutputGate}.swift`
- Test: `Packages/DMXCore/Tests/ShowModelTests/TemplateTests.swift`, `Packages/DMXCore/Tests/DMXOutputTests/{FrameTests,GateTests}.swift`

**Interfaces:**
- Consumes: Task 2 types.
- Produces:
  ```swift
  public enum BuiltInTemplates { public static let all: [FixtureType] } // dimmer(1), rgb(3), rgbw(4), rgbDimmerStrobe(5: intensity,r,g,b,strobe), movingHead8, movingHead16
  public struct DMXFrame: Equatable, Sendable {
    public init()                                  // 512 zeros
    public subscript(address: Int) -> UInt8 { get set } // 1-based; out-of-range get → 0, set ignored
    public var bytes: [UInt8] { get } }            // count == 512
  public enum PatchWriter {
    public static func defaults(for patch: Patch) -> DMXFrame
    public static func set(_ value: UInt8, channel index: Int, of fixture: Fixture, in frame: inout DMXFrame, patch: Patch) }
  public protocol DMXOutputDevice: AnyObject, Sendable {
    var isConnected: Bool { get }
    func send(_ frame: DMXFrame) throws }
  public final class VirtualDMXOutput: DMXOutputDevice { public private(set) var sentFrames: [DMXFrame] }
  @MainActor public final class OutputGate: ObservableObject {
    @Published public private(set) var isArmed: Bool   // starts false
    public init(device: DMXOutputDevice)
    public func arm(); public func disarm()
    public func submit(_ frame: DMXFrame) throws -> Bool } // false and no send when disarmed
  ```
  `movingHead8` channel order: pan, tilt, colorWheel, gobo, strobe, intensity, speed, macro. `movingHead16`: pan, panFine, tilt, tiltFine, speed, intensity, strobe, red, green, blue, white, colorWheel, gobo, macro, generic, generic.

- [ ] **Step 1: Failing tests:**
  - `templatesHaveExpectedCounts`: counts `[1, 3, 4, 5, 8, 16]` in that order.
  - `frameIsOneBased`: `f[1] = 255` sets `bytes[0] == 255`. `f[513] = 9` changes nothing. `f[0] == 0`.
  - `defaultsUseChannelDefaults`: a type with `defaultValue` 128 on channel 2 at address 10 gives `frame[11] == 128`.
  - `writerTargetsFixtureChannel`: set channel index 2 of a fixture at address 20 gives `frame[22]`.
  - `gateBlocksUntilArmed` (Review Focus 5): `submit` returns false and `sentFrames` is empty. After `arm()` it returns true and records one frame.
- [ ] **Step 2:** Run `swift test --package-path Packages/DMXCore`. Expected: new tests FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests. Expected: all pass.
- [ ] **Step 5:** Commit: `feat(output): templates, DMX frame, patch writer, virtual output, arming gate`.

---

### Task 4: Console targets, note map, console map model

**Files:**
- Create: `Packages/DMXCore/Sources/ShowModel/{ConsoleTarget,ConsoleMap}.swift`
- Test: `Packages/DMXCore/Tests/ShowModelTests/ConsoleMapTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum ConsoleTarget: Hashable, Codable, Sendable, Comparable {
    case scene(bank: Int, scene: Int), chase(Int), blackout
    public func noteNumber() throws -> UInt8      // spec 5.1 formula
    public static var allReachable: [ConsoleTarget] } // 120 scenes + 6 chases + blackout, ascending note
  public enum ConsoleError: Error, Equatable {
    case bankNotReachable(Int), sceneOutOfRange(Int), chaseOutOfRange(Int),
         midiChannelOutOfRange(Int), notArmed, sendFailed(String), noDestination }
  public struct ConsoleCell: Codable, Hashable, Sendable { public var name: String; public var colorHex: String; public var notes: String }
  public struct ConsoleLook: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID; public var name: String; public var targets: Set<ConsoleTarget> } // blackout not allowed
  public struct ConsoleMap: Codable, Equatable, Sendable {
    public var midiChannel: Int                   // 1…16, default 1
    public var noteOffDelayMs: Int?               // default 50, nil = never send Note Off
    public var cells: [ConsoleTarget: ConsoleCell]
    public var looks: [ConsoleLook]
    public func validate() -> [ConsoleError] }
  ```
  `Comparable` orders by note number (blackout last).

- [ ] **Step 1: Failing tests:**
  - `noteNumbers`: `scene(1,1)→0`, `scene(1,8)→7`, `scene(2,1)→8`, `scene(15,8)→119`, `chase(1)→120`, `chase(6)→125`, `blackout→126`.
  - `unreachableRejected` (Review Focus 4): `scene(16,1)` throws `.bankNotReachable(16)`, `scene(1,9)` throws `.sceneOutOfRange(9)`, `chase(7)` throws `.chaseOutOfRange(7)`, `scene(0,1)` throws `.bankNotReachable(0)`.
  - `allReachableCount`: 127 targets, note numbers 0…126 exactly once each.
  - `midiChannelValidated`: a channel of 17 gives `validate()` containing `.midiChannelOutOfRange(17)`.
  - `codableRoundTrip` for `ConsoleMap` with cells and a look.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests. Expected: all pass.
- [ ] **Step 5:** Commit: `feat(model): console targets, note map and console map`.

---

### Task 5: Believed console state and look diffing

**Files:**
- Create: `Packages/DMXCore/Sources/ConsoleMIDI/ConsoleState.swift`
- Test: `Packages/DMXCore/Tests/ConsoleMIDITests/ConsoleStateTests.swift`

**Interfaces:**
- Consumes: `ConsoleTarget`, `ConsoleLook`.
- Produces:
  ```swift
  public struct ConsoleState: Equatable, Sendable {
    public private(set) var on: Set<ConsoleTarget>        // scenes/chases believed on
    public private(set) var blackout: Bool
    public init()
    public func toggles(toReach target: Set<ConsoleTarget>) -> [ConsoleTarget] // symmetric difference, sorted ascending
    public mutating func applyToggle(_ t: ConsoleTarget)  // blackout flips `blackout`; others flip membership
    public mutating func reset() }                        // all off, blackout false
  ```

- [ ] **Step 1: Failing tests:**
  - `diffTurnsOffAndOn`: with {scene(1,1), scene(1,2)} on and target {scene(1,2), chase(1)}, toggles are `[scene(1,1), chase(1)]`.
  - `sameLookNoToggles`: the same set gives `[]`.
  - `blackoutFlips`: applying blackout twice gives `blackout == false`.
  - `resetClears`.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests. Expected: all pass.
- [ ] **Step 5:** Commit: `feat(console): believed state and look diffing`.

---

### Task 6: MIDI sending and ConsoleController

**Files:**
- Create: `Packages/DMXCore/Sources/ConsoleMIDI/{MIDIMessage,MIDISender,CoreMIDISender,RecordingMIDISender,ConsoleController}.swift`
- Test: `Packages/DMXCore/Tests/ConsoleMIDITests/{MIDIMessageTests,ConsoleControllerTests}.swift`

**Interfaces:**
- Consumes: Tasks 4–5.
- Produces:
  ```swift
  public struct MIDIMessage: Equatable, Sendable {
    public let bytes: [UInt8]
    public static func noteOn(channel: Int, note: UInt8, velocity: UInt8 = 127) throws -> MIDIMessage // channel 1…16; velocity 0 → throws
    public static func noteOff(channel: Int, note: UInt8) throws -> MIDIMessage }               // 0x80 | ch-1, note, 0
  public struct MIDIDestinationInfo: Hashable, Sendable { public let uniqueID: Int32; public let name: String }
  public protocol MIDISender: AnyObject, Sendable {
    var isConnected: Bool { get }
    func send(_ message: MIDIMessage) throws }
  public final class CoreMIDISender: MIDISender {
    public static func destinations() -> [MIDIDestinationInfo]
    public init(destinationUniqueID: Int32) throws }      // MIDIClientCreateWithBlock + MIDIOutputPortCreate, MIDISendEventList (MIDI 1.0 UMP) or MIDISend
  public final class RecordingMIDISender: MIDISender {
    public var isConnected: Bool; public var failNextSend: Bool; public private(set) var sent: [MIDIMessage] }
  @MainActor public final class ConsoleController: ObservableObject {
    @Published public private(set) var state: ConsoleState
    @Published public var isArmed: Bool                   // false at init
    public init(sender: MIDISender, map: ConsoleMap)
    public var map: ConsoleMap
    public func fire(_ target: ConsoleTarget) async throws      // one toggle
    public func recall(_ look: ConsoleLook) async throws        // toggles(toReach:)
    public func toggleBlackout() async throws
    public func sendRaw(note: UInt8, velocity: UInt8, channel: Int) async throws // MIDI test panel; still requires arm
    public func markAllOff() }                                   // console reset (spec 5.4)
  ```
  Each toggle sends Note On (vel 127). If `map.noteOffDelayMs` isn't nil, it then sleeps that long and sends Note Off. State changes **only after** the Note On send succeeds. `recall` stops at the first failure, and toggles already sent stay applied.

- [ ] **Step 1: Failing tests:**
  - `noteOnBytes`: `noteOn(channel: 1, note: 0)` gives `[0x90, 0, 127]`. Channel 16 gives status `0x9F`. Velocity 0 throws. Channel 17 throws.
  - `fireSendsNoteOnThenOff`: with the map's channel 3, `fire(.scene(bank: 2, scene: 1))` sends `[[0x92,8,127],[0x82,8,0]]`, and state contains the scene.
  - `noNoteOffWhenDisabled`: with `noteOffDelayMs = nil`, only the Note On is sent.
  - `notArmedSendsNothing` (Review Focus 5): it throws `.notArmed`, `sent` is empty and state is unchanged.
  - `sendFailureKeepsState` (Review Focus 2): with `failNextSend = true`, it throws `.sendFailed`, and state is unchanged.
  - `recallSendsOnlyDiff`: from {scene(1,1)}, recalling a look {scene(1,2)} sends notes 0 and 1 only.
  - `unreachableNeverSends` (Review Focus 4): `fire(.scene(bank: 20, scene: 1))` throws and `sent` is empty.
  Tests use `noteOffDelayMs = 0` for speed, except the test that checks delay presence.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement. `CoreMIDISender` is not unit-tested. Wrap CoreMIDI `OSStatus` errors as `ConsoleError.sendFailed(String)`. `isConnected` is false when the destination's uniqueID no longer resolves (`MIDIObjectFindByUniqueID`).
- [ ] **Step 4:** Run the tests. Expected: all pass.
- [ ] **Step 5:** Commit: `feat(console): MIDI sender and console controller`.

---

### Task 7: Show document

**Files:**
- Create: `Packages/DMXCore/Sources/ShowModel/Show.swift`
- Create: `App/ShowDocument.swift`
- Test: `Packages/DMXCore/Tests/ShowModelTests/ShowFileTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct Show: Codable, Equatable, Sendable {
    public static let currentFormatVersion = 1
    public var formatVersion: Int; public var patch: Patch; public var console: ConsoleMap
    public init()                                          // patch empty, console default
    public static func decode(_ data: Data) throws -> Show // throws ShowFileError
    public func encode() throws -> Data }                  // pretty-printed, sorted keys
  public enum ShowFileError: Error, Equatable { case corrupt, newerVersion(Int) }
  // App: struct ShowDocument: FileDocument, readableContentTypes [.dmxShow]; package with "show.json"
  ```
  `ConsoleMap()` default: channel 1, Note Off 50 ms, empty cells and looks.

- [ ] **Step 1: Failing tests:** `roundTrip`; `garbageIsCorrupt` (`Data("x".utf8)` → `.corrupt`); `newerVersionRejected` (`formatVersion: 2` → `.newerVersion(2)`) (Review Focus 3).
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement `Show`. Implement `ShowDocument` as a `FileDocument` using a `FileWrapper` directory containing `show.json`. SwiftUI's document system handles autosave and atomic writes. The App uses `DocumentGroup(newDocument: ShowDocument())`.
- [ ] **Step 4:** Run `swift test` and `xcodebuild … build`. Expected: pass / BUILD SUCCEEDED.
- [ ] **Step 5:** Commit: `feat: show file format and document`.

---

### Task 8: Config panel UI (fixture types, fixtures, touch test)

**Files:**
- Create: `App/Config/{ConfigView,FixtureTypeEditor,ChannelRow,PatchTable,AddFixturesSheet,TouchFaderPanel,ChannelMonitorView}.swift`
- Create: `App/AppModel.swift` (owns `OutputGate` with `VirtualDMXOutput` in plan 1, `ConsoleController`, and the current `DMXFrame`)
- Test: `UITests/ConfigFlowUITests.swift` (add a `DMXBridgeUITests` target to `project.yml`)

**Interfaces:**
- Consumes: `Patch`, `BuiltInTemplates`, `PatchWriter`, `OutputGate`, `DMXFrame`.
- Produces: `ConfigView(document: Binding<ShowDocument>)`, shown as the "Config" tab of the main window. `AppModel` is `@MainActor final class AppModel: ObservableObject` with `frame: DMXFrame`, `gate: OutputGate`, `console: ConsoleController`. Each show window has one.

UI requirements (spec goal 2, section 9):
- Left list: fixture types (+ "New from template…", duplicate, delete when unused).
- Type editor: name, and an ordered channel list with name, function picker (all `ChannelFunction` cases), default value 0–255, and value ranges (add/remove rows). Reorder by drag.
- Patch table: name, type, address, console scanner, channel count, with inline edit. Issues from `patch.validate()` appear as a red row badge and a summary banner, e.g. "Par 2 overlaps Par 1 (address 3)".
- "Add fixtures" sheet: type, count, start address (blank = auto), name prefix. It calls `Patch.addFixtures` and shows `PatchError` text inline.
- Touch panel: select a fixture to get one vertical fader per channel, labelled with the channel name/function. Moving one updates `AppModel.frame` via `PatchWriter.set` and calls `gate.submit`.
- Channel monitor: 512 small cells showing value bars, read from `AppModel.frame`.
- Toolbar: **ARM** toggle (red when armed), output status text ("Virtual output — preview only" in plan 1).

- [ ] **Step 1: Write the failing UI test** `testAddRGBFixturesShowsFourRows`: new document, Config tab, "New from template… → RGB", Add fixtures (count 4), and the patch table has 4 rows with addresses 1, 4, 7, 10. Use accessibility identifiers `patchRow.<address>`.
- [ ] **Step 2:** Run `xcodebuild test -scheme DMXBridge -destination 'platform=macOS' -only-testing:DMXBridgeUITests`. Expected: FAIL.
- [ ] **Step 3:** Implement the views.
- [ ] **Step 4:** Run the UI test. Expected: PASS. Manually check that the overlap banner appears after setting fixture 2's address to 3.
- [ ] **Step 5:** Commit: `feat(ui): fixture and channel config panel`.

---

### Task 9: Console page UI (map, looks, MIDI settings, test panel, playback)

**Files:**
- Create: `App/Console/{ConsoleView,ConsoleGrid,ConsoleCellEditor,ConsoleLooksView,MIDISettingsView,MIDITestPanel,ConsolePlaybackView}.swift`
- Modify: `App/AppModel.swift` (MIDI destination selection, persisted by uniqueID in `UserDefaults`, swapping `RecordingMIDISender` ↔ `CoreMIDISender`)
- Test: `UITests/ConsoleFlowUITests.swift`

**Interfaces:**
- Consumes: `ConsoleController`, `ConsoleMap`, `ConsoleTarget.allReachable`, `CoreMIDISender.destinations()`.
- Produces: `ConsoleView(document: Binding<ShowDocument>)` as the "Console" tab.

UI requirements (spec 5.3–5.4, 9):
- **Grid**: 15 bank rows × 8 scene columns, plus a row of 6 chases. Each cell shows its name and colour, and is **lit when believed on**. Clicking a cell (in edit mode) edits name, colour and notes. Bank 16–30 isn't shown; a footnote says "Banks 16–30 can't be reached over MIDI".
- **Playback mode**: large buttons that call `fire`. A big **BLACKOUT** button always visible (key **B**). A Looks column calls `recall`. Errors show as a red toast with the text, e.g. "MIDI interface not connected: nothing sent".
- **Looks**: create a look by selecting cells, then "Save look". Rename and delete.
- **MIDI settings**: destination picker (refresh button; "No MIDI interface found" state), MIDI channel 1–16 stepper with the hint "Must match the console: hold MIDI/Rec 3 s, Bank Up/Down, hold MIDI/Rec 3 s", and a Note Off on/off + delay field.
- **Test panel**: note 0–127, velocity 1–127, channel, Send. A log of sent messages.
- **Reset console**: a sheet with instructions ("Release all scenes on the console, press its blackout off, then press Done") that calls `markAllOff()`.
- Toolbar ARM state is shared with the Config tab (one arm for the window).

- [ ] **Step 1: Write the failing UI test** `testFiringWithoutArmShowsToast`: new document, Console tab, playback mode, tap `consoleCell.b1s1`, and the toast "Output not armed" appears. Then with a `RecordingMIDISender` injected via the launch argument `-useRecordingMIDI`, arm, tap the cell again, and the cell has accessibility value `on`.
- [ ] **Step 2:** Run the UI test. Expected: FAIL.
- [ ] **Step 3:** Implement the views and the `-useRecordingMIDI` launch-argument hook in `AppModel`.
- [ ] **Step 4:** Run all tests: `swift test --package-path Packages/DMXCore && xcodebuild test -scheme DMXBridge -destination 'platform=macOS'`. Expected: all pass.
- [ ] **Step 5:** Commit: `feat(ui): console page with MIDI playback`.

---

### Task 10: Hardware findings session docs

**Files:**
- Create: `docs/console-midi-findings.md`, `docs/hardware-test.md`

- [ ] **Step 1:** Write `docs/hardware-test.md` part 1 as a checklist for the owner:
  1. Connect the USB-MIDI cable's MIDI OUT plug to the console's MIDI socket.
  2. Set the console's MIDI channel to 1.
  3. Program scenes 1–2 of bank 1 and chase 1 on the console.
  4. In the app, pick the interface, arm, and fire each one.
  5. Run every question from spec 5.2 using the Test panel.
  6. Confirm the console label says DMX Master II and has 12 scanners.
- [ ] **Step 2:** Write `docs/console-midi-findings.md` as a table: question (each 5.2 item), result, date, app setting changed. Fill the result column with "pending".
- [ ] **Step 3:** Commit: `docs: hardware test checklist and console MIDI findings template`.

**Done for plan 1:** all tests green. The owner can define fixtures, save a `.dmxshow`, and fire console scenes, chases, looks and blackout from the Mac on the real console. Findings are recorded and feed Plan 2.
