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

private let MINFREQINBINS: Float = 5
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

private func swift_zt_auxdata_alloc(aux: inout zt_auxdata, size: Int) {
    aux.ptr = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 1)
    aux.size = size
    memset(aux.ptr, 0, size)
}

private var partialonset: [Float] = [
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

func swift_zt_ptrack_init(p: inout zt_ptrack) {
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

    swift_zt_auxdata_alloc(aux: &p.peakarray, size: (Int(p.numpks)+1)*MemoryLayout<PEAK>.size)

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
        ptrackSwift(p: &p)
        pos = 0
    }

    buf[Int(pos)] = `in`.pointee * scale
    pos += 1

    freq = p.cps
    amp = exp(p.getDBS(atIndex: p.histcnt) / 20.0 * log(10.0))

    p.cnt = pos
}

private extension zt_ptrack {
    mutating func setDBS(atIndex index: Int32, to value: Float) {
        switch index {
        case 0: dbs.0 = value
        case 1: dbs.1 = value
        case 2: dbs.2 = value
        case 3: dbs.3 = value
        case 4: dbs.4 = value
        case 5: dbs.5 = value
        case 6: dbs.6 = value
        case 7: dbs.7 = value
        case 8: dbs.8 = value
        case 9: dbs.9 = value
        case 10: dbs.10 = value
        case 11: dbs.11 = value
        case 12: dbs.12 = value
        case 13: dbs.13 = value
        case 14: dbs.14 = value
        case 15: dbs.15 = value
        case 16: dbs.16 = value
        case 17: dbs.17 = value
        case 18: dbs.18 = value
        case 19: dbs.19 = value
        default: fatalError("Illegal offset")
        }
    }

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

private func ptrackSwift(p: inout zt_ptrack) {
    let n = 2 * p.hopsize
    swift_ptrack_set_histcnt(p: &p, n: n)
    ptrack_set_spec(&p)
    var totalpower: Float = 0
    var totalloudness: Float = 0
    var totaldb: Float = 0
    swift_ptrack_set_totals(p: &p, totalpower: &totalpower, totalloudness: &totalloudness, totaldb: &totaldb, n: Int(n))
    if totaldb >= p.amplo {
        var npeak: Int32 = 0
        ptrack(
            p: &p,
            n: n,
            totalpower: totalpower,
            totalloudness: totalloudness,
            npeak: &npeak,
            maxbin: swift_ptrack_get_maxbin(n: Int(n)),
            numpks: p.numpks,
            partialonset: &partialonset,
            partialonset_count: Int32(partialonset.count)
        )
    }
}

private func swift_ptrack_set_histcnt(p: inout zt_ptrack, n: Int32) {
    var count = p.histcnt + 1
    if (count == NPREV) { count = 0 }
    p.histcnt = count
}

private func swift_ptrack_set_totals(p: inout zt_ptrack, totalpower: inout Float, totalloudness: inout Float, totaldb: inout Float, n: Int) {
    let spec = p.spec1.ptr.assumingMemoryBound(to: Float.self)
    for i in stride(from: 4 * MINBIN, to: (n - 2) * 4, by: 4) {
        let re = spec[i] - 0.5 * (spec[i - 8] + spec[i + 8])
        let im = spec[i + 1] - 0.5 * (spec[i - 7] + spec[i + 9])
        let power = re * re + im * im
        spec[i + 2] = power
        totalpower += power
        spec[i + 3] = totalpower
    }

    if totalpower > 1.0e-9 {
        totaldb = DBSCAL * logf(totalpower/Float(n))
        totalloudness = sqrtf(sqrtf(totalpower))
        if totaldb < 0 { totaldb = 0 }
    }
    else {
        totaldb = 0.0
        totalloudness = 0.0
    }

    p.setDBS(atIndex: p.histcnt, to: totaldb + DBOFFSET)
}

private func swift_ptrack_get_maxbin(n: Int) -> Float {
    var tmp = n, logn = -1
    while (tmp > 0) {
        tmp &>>= 1
        logn += 1
    }
    return Float(BINPEROCT * (logn-2))
}

private func ptrack(p: inout zt_ptrack, n: Int32, totalpower: Float, totalloudness: Float, npeak: inout Int32, maxbin: Float, numpks: Int32, partialonset: inout [Float], partialonset_count: Int32) {
    var histpeak = HISTOPEAK()
    let peaklist = p.peakarray.ptr.assumingMemoryBound(to: PEAK.self)
    let spectmp = p.spec2.ptr.assumingMemoryBound(to: Float.self)
    let histogram = spectmp.advanced(by: BINGUARD)
    let spec = p.spec1.ptr.assumingMemoryBound(to: Float.self)

    ptrack_pt2(
        &npeak,
        Int32(numpks),
        peaklist,
        totalpower,
        spec,
        Int32(n)
    )

    ptrack_pt3(
        npeak,
        numpks,
        peaklist,
        maxbin,
        histogram,
        totalloudness,
        &partialonset,
        partialonset_count
    )

    swift_ptrack_pt4(histpeak: &histpeak, maxbin: maxbin, histogram: histogram)

    var cumpow: Float = 0
    var cumstrength: Float = 0
    var freqnum: Float = 0
    var freqden: Float = 0
    var npartials: Int32 = 0
    var nbelow8: Int32 = 0

    ptrack_pt5(
        histpeak,
        npeak,
        peaklist,
        &npartials,
        &nbelow8,
        &cumpow,
        &cumstrength,
        &freqnum,
        &freqden
    )

    swift_ptrack_pt6(
        p: &p,
        nbelow8: Int(nbelow8),
        npartials: Int(npartials),
        totalpower: totalpower,
        histpeak: &histpeak,
        cumpow: cumpow,
        cumstrength: cumstrength,
        freqnum: freqnum,
        freqden: freqden,
        n: Int(n)
    )
}

private func swift_ptrack_pt4(histpeak: inout HISTOPEAK, maxbin: Float, histogram: UnsafeMutablePointer<Float>) {
    var best: Float = 0
    var indx: Int32 = -1
    for j in 0..<Int(maxbin) where histogram[j] > best {
        indx = Int32(j)
        best = histogram[j]
    }

    histpeak.hvalue = best
    histpeak.hindex = indx
}

private func swift_ptrack_pt6(p: inout zt_ptrack, nbelow8: Int, npartials: Int, totalpower: Float, histpeak: inout HISTOPEAK, cumpow: Float, cumstrength: Float, freqnum: Float, freqden: Float, n: Int) {
    if (nbelow8 < 4 || npartials < 7) && cumpow < 0.01 * totalpower {
        histpeak.hvalue = 0
    } else {
        var pitchpow = cumstrength * cumstrength
        let freqinbins = freqnum / freqden
        pitchpow = pitchpow * pitchpow

        if freqinbins < MINFREQINBINS {
            histpeak.hvalue = 0
        } else {
            let hzperbin = Float(p.sr) / Float(n + n)
            let hpitch = hzperbin * freqnum / freqden
            histpeak.hpitch = hpitch
            p.cps = hpitch
            histpeak.hloud = DBSCAL * logf(pitchpow / Float(n))
        }
    }
}
