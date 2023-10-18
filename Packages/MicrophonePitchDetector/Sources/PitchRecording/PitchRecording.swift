import AVFoundation
import MicrophonePitchDetector

enum PitchRecordingError: Error {
    case couldNotCreateAudioPCMBuffer
}

public struct PitchRecording: Codable, Equatable {
    public struct Entry: Codable, Equatable {
        public let iteration: Int
        public let pitch: Double?

        public func isApproximatelyEqual(to other: Self, pitchThreshold: Double) -> Bool {
            guard iteration == other.iteration else { return false }

            guard let pitch = pitch, let otherPitch = other.pitch else {
                return pitch == nil && other.pitch == nil
            }

            return abs(pitch - otherPitch) < pitchThreshold
        }
    }

    public var entries: [Entry] = []

    public static func record(file fileURL: URL) throws -> PitchRecording {
        let bufferSize = PitchTracker.defaultBufferSize
        let file = try AVAudioFile(forReading: fileURL)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: bufferSize
        ) else {
            throw PitchRecordingError.couldNotCreateAudioPCMBuffer
        }

        let tracker = PitchTracker(sampleRate: Int32(buffer.format.sampleRate))

        var iteration = 0
        var pitchRecording = PitchRecording()
        while true {
            do {
                try file.read(into: buffer)
            } catch {
                break
            }

            let pitch = tracker.getPitch(from: buffer, amplitudeThreshold: 0.05)
            let entry = PitchRecording.Entry(iteration: iteration, pitch: pitch)
            pitchRecording.entries.append(entry)
            iteration += 1
        }

        return pitchRecording
    }
}
