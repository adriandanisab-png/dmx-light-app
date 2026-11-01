// swift-tools-version:6.0
// Local compile check for the App sources without Xcode (see docs/decisions.md).
// Not the shipping build: that is project.yml + xcodebuild (CI).
import PackageDescription

let package = Package(
    name: "LocalApp",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../Packages/DMXCore")],
    targets: [
        .executableTarget(
            name: "DMXBridge",
            dependencies: [
                .product(name: "ShowModel", package: "DMXCore"),
                .product(name: "DMXOutput", package: "DMXCore"),
                .product(name: "ConsoleMIDI", package: "DMXCore"),
                .product(name: "Engine", package: "DMXCore"),
            ],
            exclude: ["Info.plist"]
        ),
    ]
)
