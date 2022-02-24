import CMicrophonePitchDetector

final class PitchTracker {
    private var sp: UnsafeMutablePointer<zt_data>?
    private var ptrack: UnsafeMutablePointer<zt_ptrack>?

    init(sampleRate: Int32, hopSize: Int32, peakCount: Int32) {
        _ = withUnsafeMutablePointer(to: &sp, zt_create)
        sp!.pointee.sr = sampleRate
        _ = withUnsafeMutablePointer(to: &ptrack, zt_ptrack_create)
        zt_ptrack_init(sp, ptrack, hopSize, peakCount)
    }

    deinit {
        _ = withUnsafeMutablePointer(to: &ptrack, zt_ptrack_destroy)
        _ = withUnsafeMutablePointer(to: &sp, zt_destroy)
    }

    func getPitch(frames: UnsafeMutablePointer<Float>, count: Int) -> Float? {
        var pitch: Float = 0
        var amplitude: Float = 0

        for i in 0..<count {
            zt_ptrack_compute(sp, ptrack, frames.advanced(by: i), &pitch, &amplitude)
        }

        if amplitude > 0.1 {
            return pitch
        } else {
            return nil
        }
    }
}
