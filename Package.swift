// swift-tools-version:5.9
//
// This package lets the platform-independent code in UBAccessNavigator/Core be
// unit-tested from Terminal with `swift test` (on a Mac or Linux) without a simulator.
// The iOS app itself is built from UBAccessNavigator.xcodeproj, which compiles the
// same Core files directly.
//
// It also builds the voice clip generator (`swift run anchor-voice-clips`), which
// records the Anchor voice with ElevenLabs. See Tools/VoiceClips/main.swift.

import PackageDescription

let package = Package(
    name: "NavigatorCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .library(name: "NavigatorCore", targets: ["NavigatorCore"]),
        .executable(name: "anchor-voice-clips", targets: ["VoiceClips"]),
    ],
    targets: [
        .target(
            name: "NavigatorCore",
            path: "UBAccessNavigator/Core"
        ),
        .executableTarget(
            name: "VoiceClips",
            dependencies: ["NavigatorCore"],
            path: "Tools/VoiceClips"
        ),
        .testTarget(
            name: "NavigatorCoreTests",
            dependencies: ["NavigatorCore"],
            path: "Tests/NavigatorCoreTests"
        ),
    ]
)
