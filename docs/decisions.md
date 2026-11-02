# Decisions

Deviations from the plans, with the reason.

## 2026-11-02: no Xcode on the dev Mac

The owner's Mac has only Command Line Tools (no disk space for Xcode). The built-in `Testing` module and `xcodebuild` need Xcode.

- `Packages/DMXCore/Package.swift` adds `swift-testing` (branch `release/6.2`) as a package dependency when `DMX_LOCAL_TESTING=1`. Test code is unchanged (`import Testing`). CI uses Xcode's built-in module.
- `LocalApp/` is a SwiftPM executable that symlinks `App/` so the SwiftUI sources can be compiled locally. It is a compile check only; the shipping app is `project.yml` + `xcodebuild`.
- XcodeGen, `xcodebuild` builds and XCUITests (`UITests/`) run on GitHub Actions (`macos-15`). Steps in the plans that say "Run `xcodebuild …`" are verified there, not locally.
- `scripts/local-check.sh` runs both local checks.

## 2026-11-02: plan 1 tasks 2-7 small deviations

- `ConsoleMap` test `codableRoundTrip` is named `consoleMapCodableRoundTrip` (Swift Testing function names must be unique per module; `PatchTests` uses the same name).
- `ConsoleMap` encodes `cells` as a sorted array of `{target, cell}` pairs (custom Codable) for stable JSON.
- Velocity 0 and out-of-range note/velocity throw `MIDIMessageError`; bad channel throws `ConsoleError.midiChannelOutOfRange`.
- A failed Note Off (after a successful Note On) is ignored, since the console has already toggled.

## 2026-11-02: plan 1 tasks 8-10 (UI)

- UI tests (`UITests/ConfigFlowUITests.swift`, `UITests/ConsoleFlowUITests.swift`) were written but **not run locally** (no Xcode, no XCUITest). They compile and run only in Xcode; CI on GitHub runs them. Expect to adjust element queries (tab lookup, menu items) after the first CI run.
- The shared ARM control is a `Button` (identifier `armButton`, accessibility value `on`/`off`) rather than a `Toggle`, so XCUITest sees one predictable element type. It sets both `OutputGate` and `ConsoleController.isArmed`.
- "Output not armed" toast text is exact; a separate orange hint under the Console toolbar explains arming while disarmed.
- Added `App/ShowRootView.swift` (tabs, toolbar, toast) and a Play/Edit/Select mode picker on the Console page (Select builds looks).
- Without a chosen MIDI interface the console uses a disconnected `RecordingMIDISender`, so firing shows "MIDI interface not connected: nothing sent".

## 2026-11-02: Plan 2 started before Plan 1 hardware findings

The owner asked to continue to Plan 2 (preview, fades) before running hardware test part 1. `plan-2-direct-dmx` branches from `plan-1-foundation` instead of a merged `main`. Plan 1 merges to `main` after the findings session; ConsoleController defaults are updated then.

## 2026-11-02: Plan 2 engine details

- HTP merging applies only to `.intensity` channels. Colour channels of dimmer-less types are LTP when merging playbacks (channel-wise HTP would mix colours), but grand master and blackout still scale them (`Engine.isIntensity`).
- `FixtureType.panRangeDegrees`/`tiltRangeDegrees` decode to 540/270 when absent (Plan 1 files); `Show.snapshots`/`stage` decode to empty/10x6.
- Plan 2 task 5: `OpenDMXOutput.start()` throws `openFailed` if the first open fails; reconnect retries (1 s) only apply after a successful start. `opendmx-probe` is an executable target in DMXCore (debug-only body via `#if DEBUG`).

## 2026-11-02: Plan 2 tasks 7-10 (UI)

- No view uses `@EnvironmentObject` any more: all existing and new views take `AppModel` explicitly (`@ObservedObject var model`), including sheets and toolbar items. `.environmentObject(model)` was removed from `ShowRootView`. `StageView` therefore takes an extra `model:` parameter beyond the plan's `StageView(document:selection:)`, and `selection` is a `Binding<[UUID]>` backed by `AppModel.programmer.selection`.
- `AppModel` no longer owns `OutputGate`/`VirtualDMXOutput`/`frame`; the Plan 1 touch faders write into the programmer (so they show the "Programmer active" banner) and the channel monitor reads `runner.latestFrame()`.
- The Open DMX port is opened only when ARM is pressed (and closed on disarm), so nothing at all is on the DMX line while disarmed. Output mode, port and refresh rate are locked while armed.
- Fades start from a render without grand master, blackout and programmer, so GM/programmer don't cause jumps. Channels used by a replaced playback but not by the new snapshot return to defaults immediately (engine limitation, no fade-out). Releasing a layered snapshot is instant.
- Fade time is shown on every playback button and edited in a field for the last-clicked button (`fadeTimeField`).
- In Console mode the playback page shows the Plan 1 looks as buttons (console cells stay in the Console tab) and BLACKOUT fires the console blackout.
- The Library is a list in the Programmer tab (`librarySnapshot.N`). The `frameSum=N` debug value is the accessibility value of `outputStatus`; the UI test asserts `frameSum=0` after blackout.
- `OpenDMXOutput` send loop now uses absolute deadlines: with relative sleeps `refreshRateApprox` measured 25 writes/s instead of 30 under load (sleep overshoot accumulated).
- New UI tests (`StageUITests`, `ProgrammerUITests`, `PlaybackUITests`, shared `UITestSupport.swift`) were not run locally; expect query adjustments after the first CI run.

## 2026-11-02: Stage drag not covered by a UI test

Plan 2 Task 7 asked for a UI test that drags a fixture on the stage. On GitHub's macOS runners the synthetic XCUITest drag selects the fixture but never reaches the SwiftUI `DragGesture` (seen in the test's screen recording). The owner confirmed dragging works by hand. `StageUITests` now checks that new fixtures are placed inside the stage and that clicking one selects it. Dragging stays a manual check.

## 2026-11-02: stage preview on the Playback page

Owner request: see the whole show while playing back. The Playback page shows a read-only `StageView` (`editable: false`) beside the controls, in a resizable split.
