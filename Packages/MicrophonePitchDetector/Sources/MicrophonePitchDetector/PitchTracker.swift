import AVFoundation
import CMicrophonePitchDetector

public final class PitchTracker {
    private var data: UnsafeMutablePointer<zt_data>?
    private var ptrack: UnsafeMutablePointer<zt_ptrack>?

    public static var defaultBufferSize: UInt32 { 4_096 }

    public init(sampleRate: Int32, hopSize: Int32 = Int32(PitchTracker.defaultBufferSize), peakCount: Int32 = 20) {
        withUnsafeMutablePointer(to: &data, swift_zt_create)
        data!.pointee.sr = sampleRate
        ptrack = UnsafeMutablePointer<zt_ptrack>.allocate(capacity: 1)
        ptrack!.initialize(to: zt_ptrack())
        swift_zt_ptrack_init(sp: data!, p: ptrack!, ihopsize: Int(hopSize), ipeaks: Int(peakCount))
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

// MARK: - Ported from ptrack.c

private let MINFREQINBINS = 5
private let MAXWINSIZ = 8192
private let MINWINSIZ = 128
private let NPREV = 20
private let MINBW: Float = 0.03
private let BINPEROCT = 48
private let BPEROOVERLOG2: Float = 69.24936196
private let FACTORTOBINS: Float = 4/0.0145453
private let BINGUARD = 10
private let PARTIALDEVIANCE: Float = 0.023
private let DBSCAL: Float = 3.333
private let DBOFFSET: Float = -92.3
private let MINBIN = 3
private let MINAMPS = 40

private let THRSH: Float = 10

private let COEF1: Float = 0.5 * 1.227054
private let COEF2: Float = 0.5 * -0.302385
private let COEF3: Float = 0.5 * 0.095326
private let COEF4: Float = 0.5 * -0.022748
private let COEF5: Float = 0.5 * 0.002533
private let FLTLEN = 5

private let NPARTIALONSET = Int(partialonset.count)

private func swift_zt_auxdata_alloc(aux: inout zt_auxdata, size: Int) {
    aux.ptr = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 1)
    aux.size = size
    memset(aux.ptr, 0, size)
}

private let partialonset: [Float] = [
    0.0,
    48.0,
    76.0782000346154967102,
    96.0,
    111.45254855459339269887,
    124.07820003461549671089,
    134.75303625876499715823,
    144.0,
    152.15640006923099342109,
    159.45254855459339269887,
    166.05271769459026829915,
    172.07820003461549671088,
    177.62110647077242370064,
    182.75303625876499715892,
    187.53074858920888940907,
    192.0,
]

private func swift_zt_ptrack_init(sp: UnsafeMutablePointer<zt_data>?, p: UnsafeMutablePointer<zt_ptrack>?, ihopsize: Int, ipeaks: Int) {
    guard let sp, let p else { return }

    p.pointee.size = Float(ihopsize)

    let winsize = Int(p.pointee.size*2)
    var powtwo = -1
    var tmp = winsize

    while tmp > 0 {
      tmp >>= 1
      powtwo += 1
    }

    zt_fft_init(&p.pointee.fft, Int32(powtwo - 1))

    if Int(winsize) != (1 << Int(powtwo)) {
        return
    }

    p.pointee.hopsize = Int32(p.pointee.size)

    swift_zt_auxdata_alloc(aux: &p.pointee.signal, size: Int(p.pointee.hopsize) * MemoryLayout<Float>.size)
    swift_zt_auxdata_alloc(aux: &p.pointee.prev, size: (Int(p.pointee.hopsize)*2 + 4*FLTLEN)*MemoryLayout<Float>.size)
    swift_zt_auxdata_alloc(aux: &p.pointee.sin, size: (Int(p.pointee.hopsize)*2)*MemoryLayout<Float>.size)
    swift_zt_auxdata_alloc(aux: &p.pointee.spec2, size: (winsize*4 + 4*FLTLEN)*MemoryLayout<Float>.size)
    swift_zt_auxdata_alloc(aux: &p.pointee.spec1, size: (winsize*4)*MemoryLayout<Float>.size)

    let signalPointer = p.pointee.signal.ptr.bindMemory(to: Float.self, capacity: Int(p.pointee.hopsize))
    for i in 0..<Int(p.pointee.hopsize) {
        signalPointer[i] = 0.0
    }

    let prevPointer = p.pointee.prev.ptr.bindMemory(to: Float.self, capacity: winsize + 4 * FLTLEN)
    for i in 0..<winsize + 4 * FLTLEN {
        prevPointer[i] = 0.0
    }

    let sinPointer = p.pointee.sin.ptr.bindMemory(to: Float.self, capacity: Int(p.pointee.hopsize))
    for i in 0..<Int(p.pointee.hopsize) {
        sinPointer[2*i] = cos((.pi*Float(i))/(Float(winsize)))
        sinPointer[2*i+1] = -sin((.pi*Float(i))/(Float(winsize)))
    }

    p.pointee.cnt = 0
    p.pointee.numpks = Int32(ipeaks)

    swift_zt_auxdata_alloc(aux: &p.pointee.peakarray, size: (Int(p.pointee.numpks)+1)*MemoryLayout<PEAK>.size)

    p.pointee.cnt = 0
    p.pointee.histcnt = 0
    p.pointee.sr = Float(sp.pointee.sr)
    let value: Float = -144.0
    p.pointee.dbs = (
        value,
        value,
        value,
        value,
        value,
        value,
        value,
        value,
        value,
        value,
        value,
        value,
        value,
        value,
        value,
        value,
        value,
        value,
        value,
        value
    )
    p.pointee.amplo = Float(MINAMPS)
    p.pointee.npartial = 7
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
    let scale: Float = 32768.0

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
