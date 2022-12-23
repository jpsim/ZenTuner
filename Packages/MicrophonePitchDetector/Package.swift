// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MicrophonePitchDetector",
    platforms: [.macOS(.v11), .iOS(.v14), .watchOS(.v7)],
    products: [
        .library(name: "MicrophonePitchDetector", targets: ["MicrophonePitchDetector"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing",
            from: "1.10.0"
        )
    ],
    targets: [
        .executableTarget(name: "pitchbench", dependencies: ["PitchRecording"]),
        .target(name: "PitchRecording", dependencies: ["MicrophonePitchDetector"]),
        .target(name: "MicrophonePitchDetector", dependencies: ["CMicrophonePitchDetector"]),
        .target(name: "CMicrophonePitchDetector"),
        .testTarget(
            name: "MicrophonePitchDetectorTests",
            dependencies: [
                "PitchRecording",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            exclude: [
                "Resources",
                "__Snapshots__"
            ]
        )
    ]
)
