// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "ScreenReader",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "ScreenReader",
            targets: ["ScreenReader"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/rustle/AccessibilityElement.git",
            from: "0.1.7"),
        .package(
            url: "https://github.com/rustle/AX.git",
            from: "0.1.3"),
    ],
    targets: [
        .target(
            name: "ScreenReader",
            dependencies: [
                "AccessibilityElement",
                "AX",
            ]),
        .testTarget(
            name: "ScreenReaderTests",
            dependencies: ["ScreenReader"]),
    ],
    swiftLanguageVersions: [.v5]
)
