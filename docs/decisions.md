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
