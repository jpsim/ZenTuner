import AVFoundation
import CMicrophonePitchDetector

public final class PitchTracker {
    private var data: zt_data
    private var ptrack: zt_ptrack

    public static var defaultBufferSize: UInt32 { 4_096 }

    public init(sampleRate: Int32, hopSize: Float = Float(PitchTracker.defaultBufferSize), peakCount: Int32 = 20) {
        data = zt_data(sr: sampleRate, len: 5 * UInt(sampleRate), pos: 0)
        ptrack = zt_ptrack()
        ptrack.size = hopSize
        ptrack.numpks = peakCount
        swift_zt_ptrack_init(p: &ptrack, sampleRate: Float(sampleRate))
    }

    public func getPitch(from buffer: AVAudioPCMBuffer, amplitudeThreshold: Double = 0.1) -> Double? {
        guard let floatData = buffer.floatChannelData else { return nil }

        var fpitch: Float = 0
        var famplitude: Float = 0

        let frames = (0..<Int(buffer.frameLength)).map { floatData[0].advanced(by: $0) }
        for frame in frames {
            swift_zt_ptrack_compute(&data, &ptrack, frame, &fpitch, &famplitude)
        }

        let pitch = Double(fpitch)
        let amplitude = Double(famplitude)

        if amplitude > amplitudeThreshold, pitch > 0 {
            return pitch
        } else {
            return nil
        }
    }
}
