import AVFoundation
import CMicrophonePitchDetector

public final class PitchTracker {
    private var ptrack = zt_ptrack()

    public static var defaultBufferSize: UInt32 { 4_096 }

    public init(sampleRate: Int32, hopSize: Double = Double(PitchTracker.defaultBufferSize), peakCount: Int = 20) {
        ptrack.size = hopSize
        ptrack.numpks = peakCount
        ptrack.sr = Double(sampleRate)
        swift_zt_ptrack_init(p: &ptrack)
    }

    public func getPitch(from buffer: AVAudioPCMBuffer, amplitudeThreshold: Double = 0.1) -> Double? {
        guard let floatData = buffer.floatChannelData else { return nil }

        var pitch = 0.0
        var amplitude = 0.0

        let frames = (0..<Int(buffer.frameLength)).map { floatData[0].advanced(by: $0) }
        for frame in frames {
            swift_zt_ptrack_compute(&ptrack, frame, &pitch, &amplitude)
        }

        if Double(amplitude) > amplitudeThreshold, pitch > 0 {
            return pitch
        } else {
            return nil
        }
    }
}
