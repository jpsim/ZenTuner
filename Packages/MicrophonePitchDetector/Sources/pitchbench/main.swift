import Foundation
import MicrophonePitchDetector
import PitchRecording

private let kPianoAudioFilesDirectory = URL(fileURLWithPath: #file)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Tests/MicrophonePitchDetectorTests/Resources/piano")

let audioFiles = try FileManager.default.contentsOfDirectory(
    at: kPianoAudioFilesDirectory,
    includingPropertiesForKeys: nil
).filter { $0.pathExtension == "mp3" }

for audioFile in audioFiles {
    _ = try PitchRecording.record(file: audioFile)
}
