import AVFoundation
import MicrophonePitchDetector

struct PitchRecording: Codable, Equatable {
    private struct Entry: Codable, Equatable {
        let iteration: Int
        // Stored as a String to compare to some fixed precision
        let pitch: String?
    }

    private var entries: [Entry] = []

    static func record(file fileURL: URL) throws -> PitchRecording {
        let bufferSize = PitchTracker.defaultBufferSize
        let file = try AVAudioFile(forReading: fileURL)
        let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: bufferSize
        )!

        let tracker = PitchTracker(sampleRate: buffer.format.sampleRate)

        var iteration = 0
        var pitchRecording = PitchRecording()
        while true {
            do {
                try file.read(into: buffer)
            } catch {
                break
            }

            let pitch = tracker.getPitch(from: buffer, amplitudeThreshold: 0.05)
            let pitchDescription = pitch?.descriptionForSnapshot()
            let entry = PitchRecording.Entry(iteration: iteration, pitch: pitchDescription)
            pitchRecording.entries.append(entry)
            iteration += 1
        }

        return pitchRecording
    }
}

private extension FloatingPoint where Self: CVarArg {
    func descriptionForSnapshot() -> String {
        String(format: "%.3f", self)
    }
}
