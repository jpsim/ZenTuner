import CMicrophonePitchDetector

final class PitchTracker {
    private var data: UnsafeMutablePointer<zt_data>?
    private var ptrack: UnsafeMutablePointer<zt_ptrack>?

    init(sampleRate: Int32, hopSize: Int32, peakCount: Int32) {
        withUnsafeMutablePointer(to: &data, zt_create)
        data!.pointee.sr = sampleRate
        withUnsafeMutablePointer(to: &ptrack, zt_ptrack_create)
        zt_ptrack_init(data, ptrack, hopSize, peakCount)
    }

    deinit {
        withUnsafeMutablePointer(to: &ptrack, zt_ptrack_destroy)
        withUnsafeMutablePointer(to: &data, zt_destroy)
    }

    func getPitch(frames: [UnsafeMutablePointer<Float>]) -> Float? {
        var pitch: Float = 0
        var amplitude: Float = 0

        for frame in frames {
            zt_ptrack_compute(data, ptrack, frame, &pitch, &amplitude)
        }

        if amplitude > 0.1 {
            return pitch
        } else {
            return nil
        }
    }
}
