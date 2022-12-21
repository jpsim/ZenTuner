import AVFoundation
import ZenPTrack

public final class PitchTracker {
    private var ptrack: ZenPTrack

    public static var defaultBufferSize: UInt32 { 4_096 }

    public init(sampleRate: Double, hopSize: Double = Double(PitchTracker.defaultBufferSize), peakCount: Int = 20) throws {
        ptrack = try ZenPTrack(sampleRate: sampleRate, hopSize: hopSize, peakCount: peakCount)
    }

    public func getPitch(from buffer: AVAudioPCMBuffer, amplitudeThreshold: Double = 0.1) -> Double? {
        guard let floatData = buffer.floatChannelData else { return nil }

        var pitch = 0.0
        var amplitude = 0.0

        let frames = (0..<Int(buffer.frameLength)).map { floatData[0].advanced(by: $0) }
        for frame in frames {
            ptrack.compute(buffer: frame, pitch: &pitch, amplitude: &amplitude)
        }

        if Double(amplitude) > amplitudeThreshold, pitch > 0 {
            return pitch
        } else {
            return nil
        }
    }
}
