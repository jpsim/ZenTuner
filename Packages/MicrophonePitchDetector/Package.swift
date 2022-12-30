// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "MicrophonePitchDetector",
    platforms: [.macOS(.v13), .iOS(.v16), .watchOS(.v9)],
    products: [
        .library(name: "MicrophonePitchDetector", targets: ["MicrophonePitchDetector"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing",
            from: "1.14.2"
        )
    ],
    targets: [
        .executableTarget(
            name: "pitchbench",
            dependencies: ["PitchRecording"]
        ),
        .target(
            name: "PitchRecording",
            dependencies: ["MicrophonePitchDetector"]
        ),
        .target(
            name: "MicrophonePitchDetector",
            dependencies: ["ZenPTrack"]
        ),
        .target(
            name: "ZenPTrack",
            swiftSettings: [.unsafeFlags(["-Ounchecked"], .when(configuration: .release))]
        ),
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
