# DMX Bridge: Plan 3, Effects, Tap Tempo, Cue Lists

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Parametric effects (chases, waves, sparkle, rainbow, colour chase, strobe, pan/tilt circle and figure-8) with tap tempo, plus cue lists whose cues carry a Direct part and an optional Console part, so a show can carry on from the console after a failure. This is spec milestones 6–7.

**Architecture:** Effects are pure functions in a new `Effects` target. The `Engine` gets an effects layer between playbacks and the programmer. `CueListPlayer` is a pure state machine in `Engine`. `AppModel` turns its decisions into engine updates (Direct) or `ConsoleController.recall` calls (Console). **A chase is a cue list with auto-follow**; there's no separate chase type (YAGNI).

**Tech Stack:** Swift 6, SwiftUI, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-02-dmx-light-app-design.md` (goals 5, 6, 7; section 5.3 two-part cues). **Prerequisite:** Plans 1 and 2 merged.

## Global Constraints

- Everything in Plans 1–2 Global Constraints applies.
- Effects are **deterministic**: same effect, fixture index, time and BPM give the same output. Randomness uses a seeded hash of `(effect.id, fixtureIndex, step)`. Never use `SystemRandomNumberGenerator` in the render path.
- Tempo: BPM range **20…300**, default **120**. `Hz = BPM / 60 × rateMultiplier`, with multipliers `[0.25, 0.5, 1, 2, 4]`.
- Engine layer order: defaults → playbacks → **effects** → programmer → GM → blackout.
- Cue numbers are `Double` (1, 1.5, 2…), kept sorted. Fades in seconds `0…600`.
- The show runs in **one active mode** (`OutputMode`). A cue missing the part for the active mode is **skipped with a warning**. Switching mode keeps the current cue index (spec 5.3).
- `Show` additions use `decodeIfPresent`; `formatVersion` stays **1**.

## Review Focus

1. **Switching Direct → Console in the middle of a cue list** (the backup drill): the same cue number stays current, and the next GO fires that cue's Console part. Test in Task 5.
2. **Every cue lacks a part for the active mode:** GO doesn't loop forever or hang, and shows "No cue for this mode". Test in Task 5.
3. **An effect on fixtures that lack the attribute** (pan/tilt circle on RGB pars): it's ignored for those fixtures, without a crash. Test in Task 2.
4. **Deleting a snapshot or effect a cue uses:** the cue shows "missing" and is skipped, and the show still opens. Test in Task 5.
5. **Tap tempo with a single tap, or taps 10 s apart:** BPM is unchanged and doesn't jump to absurd values. Test in Task 3.

---

### Task 1: Effect model

**Files:**
- Create: `Packages/DMXCore/Sources/ShowModel/Effect.swift`
- Modify: `Packages/DMXCore/Sources/ShowModel/Show.swift` (add `effects: [Effect]`)
- Test: `Packages/DMXCore/Tests/ShowModelTests/EffectModelTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum EffectKind: String, Codable, CaseIterable, Sendable {
    case intensityChase, intensityWave, sparkle, rainbow, colorChase, strobe, panTiltCircle, figure8 }
  public enum EffectDirection: String, Codable, Sendable { case forward, backward, bounce }
  public struct Effect: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID; public var name: String; public var colorHex: String
    public var kind: EffectKind
    public var fixtureIDs: [UUID]          // order = chase order
    public var rateMultiplier: Double      // one of 0.25, 0.5, 1, 2, 4; default 1
    public var size: Double                // 0…1, default 1
    public var spread: Double              // 0…1 phase spread across fixtures, default 1
    public var direction: EffectDirection  // default forward
    public var colors: [RGB] }             // colorChase only, ≥ 2
  ```
- [ ] **Step 1: Failing tests:** `codableRoundTrip`; `defaults` (a new `Effect(kind: .rainbow, fixtureIDs: [])` has rate 1, size 1, spread 1, forward); `oldShowOpens` (no `effects` key gives `[]`).
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests. Expected: pass.
- [ ] **Step 5:** Commit: `feat(model): effect model`.

---

### Task 2: Effect functions

**Files:**
- Create: `Packages/DMXCore/Sources/Effects/{EffectFunctions,EffectOutput,SeededNoise}.swift` (new target `Effects` depending on `ShowModel`)
- Test: `Packages/DMXCore/Tests/EffectsTests/EffectFunctionsTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct EffectOutput: Equatable, Sendable {
    public var intensity: Double?          // 0…1
    public var color: RGB?
    public var panOffset: Double?; public var tiltOffset: Double? // −0.5…0.5 of full range, scaled by size
    public var strobeOn: Bool? }
  public enum EffectFunctions {
    public static func phase(time: TimeInterval, bpm: Double, effect: Effect, index: Int, count: Int) -> Double // 0..<1
    public static func output(effect: Effect, index: Int, count: Int, time: TimeInterval, bpm: Double) -> EffectOutput }
  public enum SeededNoise { public static func unit(_ seed: UInt64) -> Double } // splitmix64 → 0..<1
  ```
  Formulas (the implementer must match these; tests pin them):
  - `hz = bpm/60 × rateMultiplier`. `base = time × hz`. Offset `o = spread × index / max(count,1)`. Forward phase = `frac(base − o)`, backward = `frac(base + o)`, bounce = triangle of forward phase.
  - **intensityChase:** `intensity = phase < max(1/count, 0.05) ? size : 0`
  - **intensityWave:** `intensity = size × (0.5 − 0.5·cos(2π·phase))`
  - **sparkle:** step = `floor(base)`; on when `SeededNoise.unit(hash(effect.id, index, step)) < 0.2 × size`. Intensity 1 or 0.
  - **rainbow:** colour = HSV(hue: phase, sat: size, val: 1)
  - **colorChase:** colour = `colors[Int(phase × colors.count) % colors.count]`
  - **strobe:** `strobeOn = frac(base) < 0.5`. Intensity follows: 1 or 0.
  - **panTiltCircle:** pan = `0.5·size·cos(2π·phase)`, tilt = `0.5·size·sin(2π·phase)`
  - **figure8:** pan = `0.5·size·sin(2π·phase)`, tilt = `0.5·size·sin(4π·phase)/2`

- [ ] **Step 1: Failing tests** (120 BPM, so hz 2):
  - `chaseSteps`: 4 fixtures, spread 1, t=0: index 0 on, others off. At t=0.125 (phase 0.25 for index 0), index 1 is on, because `frac(0.25 − 0.25) = 0 < 0.25`.
  - `waveHalfway`: t=0.25 (phase 0.5) gives intensity == size.
  - `sparkleDeterministic`: two calls with the same inputs are equal. Over 1000 steps, the on-ratio is between 0.15 and 0.25 at size 1.
  - `rainbowHue`: phase 0 gives red, phase 1/3 gives green (±0.01).
  - `colorChaseIndexes`: 3 colours, phase 0.4 gives colours[1].
  - `bounceReverses`: bounce phase at base 0.75 equals 0.5.
  - `circleRadius`: for any t, `sqrt(pan²+tilt²) == 0.5·size` (±1e-9).
- [ ] **Step 2:** Run `swift test --package-path Packages/DMXCore --filter EffectFunctionsTests`. Expected: FAIL.
- [ ] **Step 3:** Implement. Add the target and test target to `Package.swift`.
- [ ] **Step 4:** Run the tests. Expected: pass.
- [ ] **Step 5:** Commit: `feat(effects): deterministic effect functions`.

---

### Task 3: Tap tempo

**Files:**
- Create: `Packages/DMXCore/Sources/Effects/TapTempo.swift`
- Test: `Packages/DMXCore/Tests/EffectsTests/TapTempoTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct TapTempo: Sendable {
    public private(set) var bpm: Double            // starts 120
    public mutating func tap(at time: TimeInterval)
    public mutating func set(bpm: Double) }        // clamped 20…300
  ```
  Keep the taps from the last 2 s window (a gap > 2 s resets the sequence). Once there are ≥ 2 taps, BPM = 60 / median of the last ≤ 4 intervals, clamped to 20…300.
- [ ] **Step 1: Failing tests:** `fourTapsAt0_5s` gives 120; `singleTapNoChange` (Review Focus 5); `gapResets` (taps at 0, 0.5, then 10, 10.25 give 240); `clampHigh` (taps 0.05 s apart give 300).
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests. Expected: pass.
- [ ] **Step 5:** Commit: `feat(effects): tap tempo`.

---

### Task 4: Engine effects layer

**Files:**
- Modify: `Packages/DMXCore/Sources/Engine/Engine.swift` (`EngineInput` gains `runningEffects: [RunningEffect]`, `bpm: Double`). `Engine` target now depends on `Effects`.
- Create: `Packages/DMXCore/Sources/Engine/RunningEffect.swift`
- Test: `Packages/DMXCore/Tests/EngineTests/EngineEffectsTests.swift`

**Interfaces:**
- Consumes: `EffectFunctions.output`, `Attributes`.
- Produces:
  ```swift
  public struct RunningEffect: Equatable, Sendable {
    public var effectID: UUID; public var startedAt: TimeInterval; public var level: Double } // level 0…1 = effect master
  // EngineInput: public var effects: [UUID: Effect]; public var runningEffects: [RunningEffect]; public var bpm: Double
  ```
  Applying an output to a fixture: intensity sets the intensity channel (or scales colour channels when there's none) to `underlying × (1 − level) + output × level`. Colour sets colour via `Attributes.setColor`, blended by `level`. Pan/tilt adds the offset to the underlying 16-bit position, clamped. `strobeOn == false` forces intensity-class channels to 0. Time passed to the functions = `time − startedAt`. **Fixtures lacking the attribute are skipped** (Review Focus 3).
- [ ] **Step 1: Failing tests:** `waveOnDimmers` (golden frame at t=0.25 s); `rainbowOverSnapshot` (an effect at level 1 replaces the snapshot's colour; at level 0.5 the colour is halfway); `panTiltOnParsIgnored` (an RGB par's channels are unchanged and there's no crash); `programmerStillWins`; `blackoutStillWins`.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run all `EngineTests`. Expected: pass (the Plan 2 golden tests are unchanged).
- [ ] **Step 5:** Commit: `feat(engine): effects layer`.

---

### Task 5: Cue model and cue list player

**Files:**
- Create: `Packages/DMXCore/Sources/ShowModel/Cue.swift`, `Packages/DMXCore/Sources/Engine/CueListPlayer.swift`
- Modify: `Show.swift` (add `cueLists: [CueList]`)
- Test: `Packages/DMXCore/Tests/EngineTests/CueListPlayerTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct DirectCuePart: Codable, Hashable, Sendable { public var snapshotIDs: [UUID]; public var effectIDs: [UUID] }
  public enum ConsoleCuePart: Codable, Hashable, Sendable { case look(UUID), targets(Set<ConsoleTarget>) }
  public enum CueFollow: Codable, Hashable, Sendable { case manual, auto(after: Double) } // seconds after the fade completes
  public struct Cue: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID; public var number: Double; public var name: String
    public var fade: Double; public var follow: CueFollow
    public var direct: DirectCuePart?; public var console: ConsoleCuePart? }
  public struct CueList: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID; public var name: String; public var cues: [Cue]; public var loops: Bool }
  public enum CueMode: Sendable { case direct, console }   // previewOnly plays the Direct part
  public enum CueAction: Equatable, Sendable {
    case playDirect(Cue), playConsole(Cue), skipped(Cue, reason: String), end }
  public struct CueListPlayer: Sendable {
    public init(list: CueList, show: Show)
    public private(set) var currentIndex: Int?            // nil = not started
    public mutating func go(mode: CueMode) -> [CueAction]  // skipped… then one play, or end
    public mutating func back(mode: CueMode) -> [CueAction]
    public mutating func jump(to number: Double, mode: CueMode) -> [CueAction]
    public func nextAutoFollow(at time: TimeInterval, cueStartedAt: TimeInterval) -> Bool }
  ```
  A Direct part counts as **missing** when it's nil or all of its referenced IDs are gone from the show. A Console part counts as missing when it's nil or the look ID is gone. `go` walks forward, emitting `.skipped` for each unusable cue, and stops at the first playable cue. If it reaches the end it wraps once when `loops`, otherwise emits `.end`. It never visits a cue twice in one call (Review Focus 2).

- [ ] **Step 1: Failing tests:**
  - `goPlaysInOrder`: three direct cues give `.playDirect(1)`, then `.playDirect(2)`.
  - `skipsCueWithoutModePart`: cue 2 has no console part, so in console mode: `.playConsole(1)`, then `[.skipped(2, …), .playConsole(3)]`.
  - `modeSwitchKeepsIndex` (Review Focus 1): GO direct ×2, then GO console plays cue 3's console part.
  - `allMissingEndsNoHang` (Review Focus 2): no console parts with `loops = true` returns `skipped×3, .end` and terminates.
  - `deletedSnapshotMakesCueMissing` (Review Focus 4).
  - `autoFollow`: `.auto(after: 2)`, fade 1, gives true at start+3.0 and false at 2.9.
  - `cuesSortedByNumber`: inserting 1.5 between 1 and 2 gives play order 1, 1.5, 2.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests. Expected: pass.
- [ ] **Step 5:** Commit: `feat(engine): two-part cues and cue list player`.

---

### Task 6: Effects UI and tap tempo

**Files:**
- Create: `App/Library/{LibraryView,EffectEditor,EffectRow}.swift`, `App/Playback/TapTempoButton.swift`
- Modify: `App/AppModel.swift` (`startEffect(id:level:)`, `stopEffect(id:)`, `tapTempo`), `App/Playback/PlaybackView.swift` (effects as playback buttons, with an effect-master fader per active effect)
- Test: `UITests/EffectsUITests.swift`

Requirements: the Library tab has three sections (Snapshots / Effects / Cue lists) with create, duplicate, rename, colour and delete. The effect editor has a kind picker, a fixture list using the **current programmer selection order** ("Use selection" button), rate multiplier segmented control, size, spread, direction, and a colour list for colorChase. It previews live on the stage while editing (start the effect at level 1 while the editor is open and stop it on close). The playback page has a **TAP** button (key **T**) and a BPM readout that can be edited directly.

- [ ] **Step 1: Failing UI test** `testCreateRainbowAndPlay`: select 4 fixtures, then New effect → Rainbow → Use selection → Save. The playback page shows a "Rainbow" button. Click it and it shows `on`.
- [ ] **Step 2:** Run the test. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the test. Expected: PASS.
- [ ] **Step 5:** Commit: `feat(ui): effects editor, effect playback, tap tempo`.

---

### Task 7: Cue list UI and playback integration

**Files:**
- Create: `App/Library/{CueListEditor,CueRow,CuePartEditor}.swift`, `App/Playback/CueListPanel.swift`
- Modify: `App/AppModel.swift` (`activeCueList`, `go()`, `back()`, a 20 Hz auto-follow timer on the main actor, mapping `CueAction` → engine updates / `ConsoleController.recall` / warning toasts)
- Test: `UITests/CueListUITests.swift`

Requirements: the cue list editor is a table with number, name, fade, follow, and two columns **Direct** and **Console**. Each cell is a picker (snapshots + effects / console look or cell targets), and an orange "missing" badge marks a cue without a part. A banner reads "N cues have no console backup". The playback page has a cue panel showing the current and next cue, **GO** (Space), **Back**, and the mode. Mapping actions: `playDirect` replaces the playbacks with the cue's snapshots using `cue.fade`, and starts the cue's effects, stopping effects not in the cue. `playConsole` calls `console.recall`. For `.targets(set)`, it passes a transient `ConsoleLook(id: UUID(), name: "", targets: set)`. `skipped` shows a toast "Skipped cue 2: no console part". Changing `OutputMode` while a list is active keeps `currentIndex`.

- [ ] **Step 1: Failing UI test** `testGoAdvancesAndModeSwitchSkips`: a list with cue 1 (direct + console) and cue 2 (direct only). GO shows current "1". Switch the mode to Console (with recording MIDI), GO, and a toast says "Skipped cue 2".
- [ ] **Step 2:** Run the test. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run all tests: `swift test --package-path Packages/DMXCore && xcodebuild test -scheme DMXBridge -destination 'platform=macOS'`. Expected: all pass.
- [ ] **Step 5:** Commit: `feat(ui): cue lists with two-part cues and GO playback`.

---

### Task 8: Hardware test part 3

**Files:**
- Modify: `docs/hardware-test.md`

- [ ] **Step 1:** Add part 3, the owner's checklist:
  1. Build a 4-cue list where every cue has a Console part.
  2. Run it in Direct mode.
  3. At cue 2, simulate a failure: pull the USB cable, move the DMX cable to the console, switch the mode to Console, and press GO. Cue 3 should come up from the console.
  4. Run a rainbow and a chase at TAP-set tempo for 10 minutes and note any flicker.
- [ ] **Step 2:** Commit: `docs: hardware test part 3 (cue backup drill)`.

**Done for plan 3:** the owner can build effects and cue lists, run a show with GO, and carry on from the console if the Mac side fails.
