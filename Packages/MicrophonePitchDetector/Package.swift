// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MicrophonePitchDetector",
    platforms: [.macOS(.v11), .iOS(.v14), .watchOS(.v7)],
    products: [
        .library(name: "MicrophonePitchDetector", targets: ["MicrophonePitchDetector"])
    ],
    targets: [
        .target(name: "MicrophonePitchDetector", dependencies: ["CMicrophonePitchDetector"]),
        .target(name: "CMicrophonePitchDetector")
    ]
)
