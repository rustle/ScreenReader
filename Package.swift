// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ScreenReader",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "ScreenReader",
            targets: ["ScreenReader"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/rustle/AccessibilityElement.git",
            from: "0.1.14"),
        .package(
            url: "https://github.com/rustle/AX.git",
            from: "0.1.10"),
        .package(
            url: "https://github.com/rustle/TargetAction.git",
            from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "ScreenReader",
            dependencies: [
                "AccessibilityElement",
                "AX",
                "TargetAction",
            ]),
        .testTarget(
            name: "ScreenReaderTests",
            dependencies: ["ScreenReader"]),
    ],
    swiftLanguageVersions: [.v5]
)
