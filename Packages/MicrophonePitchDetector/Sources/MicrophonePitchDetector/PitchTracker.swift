import AVFoundation
import CMicrophonePitchDetector

public final class PitchTracker {
    private var data: UnsafeMutablePointer<zt_data>?
    private var ptrack: UnsafeMutablePointer<zt_ptrack>?

    public static var defaultBufferSize: UInt32 { 4_096 }

    public init(sampleRate: Int32, hopSize: Int32 = Int32(PitchTracker.defaultBufferSize), peakCount: Int32 = 20) {
        withUnsafeMutablePointer(to: &data, zt_create)
        data!.pointee.sr = sampleRate
        withUnsafeMutablePointer(to: &ptrack, zt_ptrack_create)
        zt_ptrack_init(data, ptrack, hopSize, peakCount)
    }

    deinit {
        withUnsafeMutablePointer(to: &ptrack, zt_ptrack_destroy)
        withUnsafeMutablePointer(to: &data, zt_destroy)
    }

    public func getPitch(from buffer: AVAudioPCMBuffer, amplitudeThreshold: Double = 0.1) -> Double? {
        guard let floatData = buffer.floatChannelData else { return nil }

        var fpitch: Float = 0
        var famplitude: Float = 0

        let frames = (0..<Int(buffer.frameLength)).map { floatData[0].advanced(by: $0) }
        for frame in frames {
            zt_ptrack_compute(data, ptrack, frame, &fpitch, &famplitude)
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
