import AVFoundation
import CMicrophonePitchDetector

public final class PitchTracker {
    private var data: UnsafeMutablePointer<zt_data>?
    private var ptrack: UnsafeMutablePointer<zt_ptrack>?

    public static var defaultBufferSize: UInt32 { 4_096 }

    public init(sampleRate: Int32, hopSize: Int32 = Int32(PitchTracker.defaultBufferSize), peakCount: Int32 = 20) {
        withUnsafeMutablePointer(to: &data, swift_zt_create)
        data!.pointee.sr = sampleRate
        withUnsafeMutablePointer(to: &ptrack, zt_ptrack_create)
        zt_ptrack_init(data, ptrack, hopSize, peakCount)
    }

    deinit {
        withUnsafeMutablePointer(to: &ptrack, zt_ptrack_destroy)
        withUnsafeMutablePointer(to: &data, swift_zt_destroy)
    }

    public func getPitch(from buffer: AVAudioPCMBuffer, amplitudeThreshold: Double = 0.1) -> Double? {
        guard let floatData = buffer.floatChannelData else { return nil }

        var fpitch: Float = 0
        var famplitude: Float = 0

        let frames = (0..<Int(buffer.frameLength)).map { floatData[0].advanced(by: $0) }
        for frame in frames {
            swift_zt_ptrack_compute(data, ptrack, frame, &fpitch, &famplitude)
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

private func swift_zt_ptrack_compute(
    _ sp: UnsafeMutablePointer<zt_data>!,
    _ p: UnsafeMutablePointer<zt_ptrack>!,
    _ in: UnsafeMutablePointer<Float>!,
    _ freq: UnsafeMutablePointer<Float>!,
    _ amp: UnsafeMutablePointer<Float>!
) {
    let buf = p.pointee.signal.ptr.bindMemory(to: Float.self, capacity: 1)
    var pos = p.pointee.cnt
    let h = p.pointee.hopsize
    let scale = p.pointee.dbfs

    if pos == h {
        ptrack(sp, p)
        pos = 0
    }
    buf[Int(pos)] = `in`.pointee * scale
    pos += 1

    freq.pointee = p.pointee.cps
    amp.pointee =  exp(p.pointee.getDBS(atIndex: p.pointee.histcnt) / 20.0 * log(10.0))

    p.pointee.cnt = pos
}

private extension zt_ptrack {
    func getDBS(atIndex index: Int32) -> Float {
        switch index {
        case 0: return dbs.0
        case 1: return dbs.1
        case 2: return dbs.2
        case 3: return dbs.3
        case 4: return dbs.4
        case 5: return dbs.5
        case 6: return dbs.6
        case 7: return dbs.7
        case 8: return dbs.8
        case 9: return dbs.9
        case 10: return dbs.10
        case 11: return dbs.11
        case 12: return dbs.12
        case 13: return dbs.13
        case 14: return dbs.14
        case 15: return dbs.15
        case 16: return dbs.16
        case 17: return dbs.17
        case 18: return dbs.18
        case 19: return dbs.19
        default: fatalError("Illegal offset")
        }
    }
}

private func swift_zt_create(_ spp: UnsafeMutablePointer<UnsafeMutablePointer<zt_data>?>) {
    spp.pointee = UnsafeMutablePointer<zt_data>.allocate(capacity: 1)
    spp.pointee?.initialize(to: zt_data())
    let sp = spp.pointee!
    let out = UnsafeMutablePointer<Float>.allocate(capacity: 1)
    out.initialize(to: 0)
    sp.pointee.out = out
    sp.pointee.sr = 44100
    sp.pointee.len = 5 * UInt(sp.pointee.sr)
    sp.pointee.pos = 0
}

private func swift_zt_destroy(_ spp: UnsafeMutablePointer<UnsafeMutablePointer<zt_data>?>) {
    guard let sp = spp.pointee else { return }
    sp.pointee.out.deallocate()
    spp.pointee?.deallocate()
}
