# DMX Bridge

Native macOS app for stage lights: direct USB-DMX output, or firing a Stairville DMX Master II console's stored scenes over MIDI.

## Build (with Xcode)

```bash
brew install xcodegen && xcodegen generate && open DMXBridge.xcodeproj
```

Tests:

```bash
swift test --package-path Packages/DMXCore
xcodebuild test -scheme DMXBridge -destination 'platform=macOS'
```

## Build without Xcode (Command Line Tools only)

```bash
scripts/local-check.sh
```

Runs the core tests (pulling `swift-testing` as a package) and compiles the app sources. UI tests and the real `.app` bundle need Xcode; GitHub Actions (`.github/workflows/ci.yml`) builds them and uploads `DMXBridge.zip`.

See `HANDOVER.md` and `docs/`.
