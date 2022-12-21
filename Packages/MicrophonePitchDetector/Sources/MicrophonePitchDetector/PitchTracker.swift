import AVFoundation
import CMicrophonePitchDetector

final class PitchTracker {
    private var data: UnsafeMutablePointer<zt_data>?
    private var ptrack: UnsafeMutablePointer<zt_ptrack>?

    static var defaultBufferSize: UInt32 { 4_096 }

    init(sampleRate: Int32, hopSize: Int32 = Int32(PitchTracker.defaultBufferSize), peakCount: Int32 = 20) {
        withUnsafeMutablePointer(to: &data, zt_create)
        data!.pointee.sr = sampleRate
        withUnsafeMutablePointer(to: &ptrack, zt_ptrack_create)
        zt_ptrack_init(data, ptrack, hopSize, peakCount)
    }

    deinit {
        withUnsafeMutablePointer(to: &ptrack, zt_ptrack_destroy)
        withUnsafeMutablePointer(to: &data, zt_destroy)
    }

    func getPitch(from buffer: AVAudioPCMBuffer, amplitudeThreshold: Float = 0.1) -> Float? {
        guard let floatData = buffer.floatChannelData else { return nil }

        var pitch: Float = 0
        var amplitude: Float = 0

        let frames = (0..<Int(buffer.frameLength)).map { floatData[0].advanced(by: $0) }
        for frame in frames {
            zt_ptrack_compute(data, ptrack, frame, &pitch, &amplitude)
        }

        if amplitude > amplitudeThreshold, pitch > 0 {
            return pitch
        } else {
            return nil
        }
    }
}
