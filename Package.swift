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
            targets: ["ScreenReader"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/rustle/AccessibilityElement.git",
            .upToNextMajor(from: "0.2.13")
        ),
        .package(
            url: "https://github.com/rustle/AX.git",
            .upToNextMajor(from: "0.2.2")
        ),
        .package(
            url: "https://github.com/rustle/Braille.git",
            .upToNextMajor(from: "1.0.0")
        ),
        .package(
            url: "https://github.com/rustle/RunLoopExecutor.git",
            .upToNextMajor(from: "1.0.0")
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
                "Braille",
                "RunLoopExecutor",
                .product(
                    name: "RunLoopExecutorPool",
                    package: "RunLoopExecutor"
                ),
                "TargetAction",
            ]
        ),
        .testTarget(
            name: "ScreenReaderTests",
            dependencies: [
                "ScreenReader",
                "AccessibilityElement",
                .product(
                    name: "AccessibilityElementMocks",
                    package: "AccessibilityElement"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
