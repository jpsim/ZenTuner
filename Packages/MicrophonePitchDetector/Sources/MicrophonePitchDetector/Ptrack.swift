/*
 * PTrack
 *
 * This code has been extracted from the Csound opcode "ptrack".
 * It has been modified to work as a Soundpipe module and modified again for use in ZenTuner.
 *
 * Original Author(s): Victor Lazzarini, Miller Puckette (Original Algorithm), Aurelius Prochazka
 * Year: 2007
 * Location: Opcodes/pitchtrack.c
 *
 */

import CMicrophonePitchDetector

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

func swift_zt_ptrack_init(p: inout zt_ptrack, sampleRate: Float) {
    let winsize = Int(p.size*2)
    var powtwo = -1
    var tmp = winsize

    while tmp > 0 {
        tmp >>= 1
        powtwo += 1
    }

    swift_zt_fft_init(p: &p, M: powtwo - 1)

    if winsize != (1 << powtwo) {
        return
    }

    p.hopsize = Int32(p.size)
    let hopsize = Int(p.hopsize)

    swift_zt_auxdata_alloc(aux: &p.signal, size: hopsize * MemoryLayout<Float>.size)
    swift_zt_auxdata_alloc(aux: &p.prev, size: (hopsize*2 + 4*FLTLEN)*MemoryLayout<Float>.size)
    swift_zt_auxdata_alloc(aux: &p.sin, size: (hopsize*2)*MemoryLayout<Float>.size)
    swift_zt_auxdata_alloc(aux: &p.spec2, size: (winsize*4 + 4*FLTLEN)*MemoryLayout<Float>.size)
    swift_zt_auxdata_alloc(aux: &p.spec1, size: (winsize*4)*MemoryLayout<Float>.size)

    let signalPointer = p.signal.ptr.bindMemory(to: Float.self, capacity: hopsize)
    for i in 0..<hopsize {
        signalPointer[i] = 0.0
    }

    let prevPointer = p.prev.ptr.bindMemory(to: Float.self, capacity: winsize + 4 * FLTLEN)
    for i in 0..<winsize + 4 * FLTLEN {
        prevPointer[i] = 0.0
    }

    let sinPointer = p.sin.ptr.bindMemory(to: Float.self, capacity: hopsize)
    for i in 0..<hopsize {
        sinPointer[2*i] = cos((.pi*Float(i))/(Float(winsize)))
        sinPointer[2*i+1] = -sin((.pi*Float(i))/(Float(winsize)))
    }

    p.cnt = 0

    swift_zt_auxdata_alloc(aux: &p.peakarray, size: (Int(p.numpks)+1)*MemoryLayout<PEAK>.size)

    p.cnt = 0
    p.histcnt = 0
    p.sr = sampleRate
    let value: Float = -144.0
    p.dbs = (
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
    p.amplo = Float(MINAMPS)
}

func swift_zt_ptrack_compute(
    _ sp: inout zt_data,
    _ p: inout zt_ptrack,
    _ in: UnsafeMutablePointer<Float>!,
    _ freq: inout Float,
    _ amp: inout Float
) {
    let buf = p.signal.ptr.bindMemory(to: Float.self, capacity: 1)
    var pos = p.cnt
    let h = p.hopsize
    let scale: Float = 32768.0

    if pos == h {
        ptrack(&sp, &p)
        pos = 0
    }

    buf[Int(pos)] = `in`.pointee * scale
    pos += 1

    freq = p.cps
    amp = exp(p.getDBS(atIndex: p.histcnt) / 20.0 * log(10.0))

    p.cnt = pos
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
