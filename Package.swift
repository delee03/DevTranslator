// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DevTranslator",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        // Main CLI executable
        .executableTarget(
            name: "devtranslator",
            dependencies: [
                "TranslationEngine",
                "Shared",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/DevTranslator"
        ),

        // Translation engine library
        .target(
            name: "TranslationEngine",
            dependencies: ["Shared"],
            path: "Sources/TranslationEngine"
        ),

        // Shared utilities
        .target(
            name: "Shared",
            path: "Sources/Shared"
        ),

        // Tests
        .testTarget(
            name: "TranslationEngineTests",
            dependencies: ["TranslationEngine", "Shared"]
        ),
    ]
)
