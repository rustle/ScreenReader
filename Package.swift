// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "ScreenReader",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "ScreenReader",
            targets: ["ScreenReader"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/rustle/AccessibilityElement.git",
            .upToNextMajor(from: "0.2.3")
        ),
        .package(
            url: "https://github.com/rustle/AX.git",
            .upToNextMajor(from: "0.2.0")
        ),
        .package(
            url: "https://github.com/rustle/TargetAction.git",
            .upToNextMajor(from: "0.2.0")
        ),
    ],
    targets: [
        .target(
            name: "ScreenReader",
            dependencies: [
                "AccessibilityElement",
                "AX",
                "TargetAction",
            ]
        ),
        .testTarget(
            name: "ScreenReaderTests",
            dependencies: ["ScreenReader"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
