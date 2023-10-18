import Foundation
import PitchRecording
import SnapshotTesting
import XCTest

private let kPianoAudioFilesDirectory = URL(fileURLWithPath: #file)
    .deletingLastPathComponent()
    .appendingPathComponent("Resources/piano")

final class MicrophonePitchDetectorTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        diffTool = "ksdiff"
        // isRecording = true
    }

    func testPiano() async throws {
        let audioFiles = try FileManager.default.contentsOfDirectory(
            at: kPianoAudioFilesDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "mp3" }

        // Running in parallel is ~7x faster on an M1 Max
        try await audioFiles.concurrentForEach { audioFile in
            let pitchRecording = try PitchRecording.record(file: audioFile)
            let name = String(audioFile.lastPathComponent.prefix(while: { $0 != "." }))
            await assertAudioFileSnapshot(matching: pitchRecording, named: name)
        }
    }
}

@MainActor
private func assertAudioFileSnapshot(
    matching recording: PitchRecording,
    named name: String,
    file: StaticString = #file,
    testName: String = #function,
    line: UInt = #line)
{
    assertSnapshot(
        matching: recording,
        as: .pitchRecording,
        named: name,
        file: file,
        testName: testName,
        line: line
    )
}

private extension Sequence {
    func concurrentForEach(_ operation: @escaping (Element) async throws -> Void) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for element in self {
                group.addTask {
                    try await operation(element)
                }
            }
            for try await _ in group {}
        }
    }
}
