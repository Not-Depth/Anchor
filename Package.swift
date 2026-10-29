// swift-tools-version:5.9
//
// This package exists only so the platform-independent code in
// UBAccessNavigator/Core can be unit-tested from Terminal with `swift test`
// (on a Mac or Linux) without a simulator. The iOS app itself is built from
// UBAccessNavigator.xcodeproj, which compiles the same Core files directly.

import PackageDescription

let package = Package(
    name: "NavigatorCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .library(name: "NavigatorCore", targets: ["NavigatorCore"]),
    ],
    targets: [
        .target(
            name: "NavigatorCore",
            path: "UBAccessNavigator/Core"
        ),
        .testTarget(
            name: "NavigatorCoreTests",
            dependencies: ["NavigatorCore"],
            path: "Tests/NavigatorCoreTests"
        ),
    ]
)
