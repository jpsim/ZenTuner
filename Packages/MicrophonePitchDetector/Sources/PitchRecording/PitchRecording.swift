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

        let tracker = PitchTracker(sampleRate: buffer.format.sampleRate)

        var pitchRecording = PitchRecording()
        for iteration in 0... {
            do {
                try file.read(into: buffer)
                let pitch = tracker.getPitch(from: buffer, amplitudeThreshold: 0.05)
                let entry = PitchRecording.Entry(iteration: iteration, pitch: pitch)
                pitchRecording.entries.append(entry)
            } catch {
                break
            }
        }
        return pitchRecording
    }
}
