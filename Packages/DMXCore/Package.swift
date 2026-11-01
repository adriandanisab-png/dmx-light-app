// swift-tools-version:6.0
import PackageDescription
import Foundation

// Without Xcode (Command Line Tools only) the built-in `Testing` module is missing.
// Set DMX_LOCAL_TESTING=1 to pull swift-testing 6.2 as a package instead.
// See docs/decisions.md. CI (Xcode) uses the built-in module.
let localTesting = ProcessInfo.processInfo.environment["DMX_LOCAL_TESTING"] == "1"
let testingDeps: [Target.Dependency] = localTesting ? [.product(name: "Testing", package: "swift-testing")] : []

let package = Package(
    name: "DMXCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ShowModel", targets: ["ShowModel"]),
        .library(name: "DMXOutput", targets: ["DMXOutput"]),
        .library(name: "ConsoleMIDI", targets: ["ConsoleMIDI"]),
        .library(name: "Engine", targets: ["Engine"]),
    ],
    dependencies: localTesting ? [.package(url: "https://github.com/swiftlang/swift-testing.git", branch: "release/6.2")] : [],
    targets: [
        .target(name: "ShowModel"),
        .target(name: "DMXOutput", dependencies: ["ShowModel"]),
        .target(name: "ConsoleMIDI", dependencies: ["ShowModel"]),
        .target(name: "Engine", dependencies: ["ShowModel", "DMXOutput"]),
        .testTarget(name: "EngineTests", dependencies: ["Engine", "DMXOutput", "ShowModel"] + testingDeps),
        .testTarget(name: "ShowModelTests", dependencies: ["ShowModel"] + testingDeps),
        .testTarget(name: "DMXOutputTests", dependencies: ["DMXOutput", "ShowModel"] + testingDeps),
        .testTarget(name: "ConsoleMIDITests", dependencies: ["ConsoleMIDI", "ShowModel"] + testingDeps),
    ]
)
