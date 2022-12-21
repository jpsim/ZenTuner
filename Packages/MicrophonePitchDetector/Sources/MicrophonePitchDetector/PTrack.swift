/*
 * PTrack
 *
 * This code has been extracted from the Csound opcode "ptrack".
 * It was rewritten in Swift by JP Simard for use in ZenTuner.
 *
 * Original Author(s): Victor Lazzarini, Miller Puckette (Original Algorithm), Aurelius Prochazka
 * Year: 2007
 * Location: Opcodes/pitchtrack.c
 *
 */

import CMicrophonePitchDetector

private let MINFREQINBINS = 5.0
private let NPREV = 20
private let MINBW = 0.03
private let BINPEROCT = 48
private let BPEROOVERLOG2: Float = 69.24936196
private let FACTORTOBINS: Float = 4/0.0145453
private let BINGUARD = 10
private let PARTIALDEVIANCE = 0.023
private let DBSCAL = 3.333
private let DBOFFSET = -92.3
private let MINBIN = 3
private let MINAMPS = 40.0

private let THRSH: Float = 10

private let COEF1: Float = 0.5 * 1.227054
private let COEF2: Float = 0.5 * -0.302385
private let COEF3: Float = 0.5 * 0.095326
private let COEF4: Float = 0.5 * -0.022748
private let COEF5: Float = 0.5 * 0.002533
private let FLTLEN = 5
private let MAGIC = sqrtf(2) / 2

struct zt_ptrack {
    var size = 0.0
    var signal = [Float]()
    var prev = [Float]()
    var sin = [Float]()
    var spec1 = [Float]()
    var spec2 = [Float]()
    fileprivate var peaklist = [PEAK]()
    var numpks = 0
    var cnt = 0
    var histcnt = 0
    var hopsize = 0
    var sr = 0.0
    var cps = 0.0
    var dbs = Array(repeating: 0.0, count: 20)
    var amplo = 0.0
    var fft = zt_fft()
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

    p.fft = swift_zt_fft_init(M: powtwo - 1)

    if winsize != (1 << powtwo) {
        return
    }

    p.hopsize = Int(p.size)

    p.signal = Array(repeating: 0, count: p.hopsize)
    p.prev = Array(repeating: 0, count: winsize + 4 * FLTLEN)
    p.sin = Array(repeating: 0, count: p.hopsize*2)
    p.spec1 = Array(repeating: 0, count: winsize*4)
    p.spec2 = Array(repeating: 0, count: winsize*4 + 4*FLTLEN)

    for i in 0..<p.hopsize {
        p.sin[2*i] = cos((.pi*Float(i))/(Float(winsize)))
        p.sin[2*i+1] = -sin((.pi*Float(i))/(Float(winsize)))
    }

    p.dbs = Array(repeating: -144.0, count: 20)
    p.amplo = MINAMPS
}

func swift_zt_ptrack_compute(
    _ p: inout zt_ptrack,
    _ in: UnsafeMutablePointer<Float>!,
    _ freq: inout Double,
    _ amp: inout Double
) {
    var pos = p.cnt
    let h = p.hopsize
    let scale: Float = 32768.0

    if pos == h {
        ptrackSwift(p: &p)
        pos = 0
    }

    p.signal[Int(pos)] = `in`.pointee * scale
    pos += 1

    freq = p.cps
    amp = Double(exp(Float(p.dbs[Int(p.histcnt)]) / 20.0 * log(10.0)))

    p.cnt = pos
}

private func ptrackSwift(p: inout zt_ptrack) {
    let n = 2 * p.hopsize
    swift_ptrack_set_histcnt(p: &p, n: n)
    swift_ptrack_set_spec(p: &p)
    var totalpower: Double = 0
    var totalloudness: Double = 0
    var totaldb: Double = 0
    swift_ptrack_set_totals(p: &p, totalpower: &totalpower, totalloudness: &totalloudness, totaldb: &totaldb, n: Int(n))
    guard totaldb >= p.amplo else {
        return
    }

    var npeak = 0
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

private func swift_ptrack_set_histcnt(p: inout zt_ptrack, n: Int) {
    var count = p.histcnt + 1
    if (count == NPREV) { count = 0 }
    p.histcnt = count
}

private func swift_ptrack_set_totals(p: inout zt_ptrack, totalpower: inout Double, totalloudness: inout Double, totaldb: inout Double, n: Int) {
    for i in stride(from: 4 * MINBIN, to: (n - 2) * 4, by: 4) {
        let re = p.spec1[i] - 0.5 * (p.spec1[i - 8] + p.spec1[i + 8])
        let im = p.spec1[i + 1] - 0.5 * (p.spec1[i - 7] + p.spec1[i + 9])
        let power = re * re + im * im
        p.spec1[i + 2] = power
        totalpower += Double(power)
        p.spec1[i + 3] = Float(totalpower)
    }

    if totalpower > 1.0e-9 {
        totaldb = DBSCAL * Double(logf(Float(totalpower)/Float(n)))
        totalloudness = Double(sqrtf(sqrtf(Float(totalpower))))
        if totaldb < 0 { totaldb = 0 }
    }
    else {
        totaldb = 0.0
        totalloudness = 0.0
    }

    p.dbs[Int(p.histcnt)] = totaldb + DBOFFSET
}

private func swift_ptrack_get_maxbin(n: Int) -> Float {
    var tmp = n, logn = -1
    while (tmp > 0) {
        tmp &>>= 1
        logn += 1
    }
    return Float(BINPEROCT * (logn-2))
}

private struct HISTOPEAK {
    var hpitch: Float = 0
    var hvalue: Float = 0
    var hloud: Double = 0
    var hindex: Int32 = 0
}

private func ptrack(p: inout zt_ptrack, n: Int, totalpower: Double, totalloudness: Double, npeak: inout Int, maxbin: Float, numpks: Int, partialonset: inout [Float], partialonset_count: Int32) {
    var histpeak = HISTOPEAK()
    func getHist(spectmp: UnsafeMutablePointer<Float>) -> UnsafeMutablePointer<Float> {
        return spectmp.advanced(by: BINGUARD)
    }
    let histogram = getHist(spectmp: &p.spec2)

    swift_ptrack_pt2(
        npeak: &npeak,
        numpks: Int(numpks),
        peaklist: &p.peaklist,
        totalpower: totalpower,
        spec: &p.spec1,
        n: Int(n)
    )

    swift_ptrack_pt3(
        npeak: &npeak,
        numpks: numpks,
        peaklist: &p.peaklist,
        maxbin: maxbin,
        histogram: histogram,
        totalloudness: totalloudness,
        partialonset: partialonset,
        partialonset_count: Int(partialonset_count)
    )

    swift_ptrack_pt4(histpeak: &histpeak, maxbin: maxbin, histogram: histogram)

    var cumpow: Float = 0
    var cumstrength: Float = 0
    var freqnum: Double = 0
    var freqden: Double = 0
    var npartials: Int32 = 0
    var nbelow8: Int32 = 0

    swift_ptrack_pt5(
        histpeak: histpeak,
        npeak: Int(npeak),
        peaklist: &p.peaklist,
        npartials: &npartials,
        nbelow8: &nbelow8,
        cumpow: &cumpow,
        cumstrength: &cumstrength,
        freqnum: &freqnum,
        freqden: &freqden
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

private struct PEAK {
    var pfreq: Float = 0
    var pwidth: Float = 0
    var ppow: Float = 0
    var ploudness: Float = 0
}

private func swift_ptrack_pt2(npeak: inout Int, numpks: Int, peaklist: UnsafeMutablePointer<PEAK>, totalpower: Double, spec: UnsafeMutablePointer<Float>, n: Int) {
    for i in stride(from: 4*MINBIN, to: 4*(n-2), by: 4) {
        if npeak >= numpks { break }
        let height = spec[i+2], h1 = spec[i-2], h2 = spec[i+6]
        var totalfreq, peakfr, tmpfr1, tmpfr2, m, `var`, stdev: Float

        if height < h1 || height < h2 || h1 < 0.00001*Float(totalpower) || h2 < 0.00001*Float(totalpower) { continue }

        peakfr = ((spec[i-8] - spec[i+8]) * (2.0 * spec[i] - spec[i+8] - spec[i-8]) +
                  (spec[i-7] - spec[i+9]) * (2.0 * spec[i+1] - spec[i+9] - spec[i-7])) / (height + height)
        tmpfr1 = ((spec[i-12] - spec[i+4]) * (2.0 * spec[i-4] - spec[i+4] - spec[i-12]) +
                  (spec[i-11] - spec[i+5]) * (2.0 * spec[i-3] - spec[i+5] - spec[i-11])) / (2.0 * h1) - 1
        tmpfr2 = ((spec[i-4] - spec[i+12]) * (2.0 * spec[i+4] - spec[i+12] - spec[i-4]) +
                  (spec[i-3] - spec[i+13]) * (2.0 * spec[i+5] - spec[i+13] - spec[i-3])) / (2.0 * h2) + 1

        m = 0.333333333333 * (peakfr + tmpfr1 + tmpfr2)
        `var` = 0.5 * ((peakfr-m)*(peakfr-m) +
                      (tmpfr1-m)*(tmpfr1-m) + (tmpfr2-m)*(tmpfr2-m))

        totalfreq = Float(i >> 2) + m
        if (`var` * Float(totalpower) > THRSH * height || `var` < 1.0e-30) {
            continue
        }

        stdev = sqrtf(`var`)
        totalfreq = max(totalfreq, 4)

        peaklist[Int(npeak)].pwidth = stdev
        peaklist[Int(npeak)].ppow = height
        peaklist[Int(npeak)].ploudness = sqrt(sqrt(height))
        peaklist[Int(npeak)].pfreq = totalfreq
        npeak += 1
    }
}

private func swift_ptrack_pt3(npeak: inout Int, numpks: Int, peaklist: UnsafeMutablePointer<PEAK>, maxbin: Float, histogram: UnsafeMutablePointer<Float>, totalloudness: Double, partialonset: [Float], partialonset_count: Int) {
    if npeak > numpks { npeak = numpks }
    for i in 0..<Int(maxbin) { histogram[i] = 0 }
    for i in 0..<Int(npeak) {
        let pit = BPEROOVERLOG2 * logf(peaklist[i].pfreq) - 96.0
        let binbandwidth = FACTORTOBINS * peaklist[i].pwidth / peaklist[i].pfreq
        let putbandwidth = binbandwidth < 2.0 ? 2.0 : binbandwidth
        let weightbandwidth = binbandwidth < 1.0 ? 1.0 : binbandwidth
        let weightamp = 4.0 * peaklist[i].ploudness / Float(totalloudness)
        for j in 0..<partialonset_count {
            let bin = pit - partialonset[j]
            if bin < maxbin {
                let score = 30.0 * weightamp / (Float((j+7)) * weightbandwidth)
                let firstbin = bin + 0.5 - 0.5 * putbandwidth
                let lastbin = bin + 0.5 + 0.5 * putbandwidth
                let ibw = lastbin - firstbin
                if firstbin < -Float(BINGUARD) { break }
                let para = 1.0 / (putbandwidth * putbandwidth)
                var pphase: Float = firstbin - bin
                for k in 0...Int(ibw) {
                    histogram[k+Int(firstbin)] += score * (1.0 - para * (pphase + Float(k)) * (pphase + Float(k)))
                    pphase += 1
                }
            }
        }
    }
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

private func swift_ptrack_pt5(histpeak: HISTOPEAK, npeak: Int, peaklist: UnsafeMutablePointer<PEAK>, npartials: inout Int32, nbelow8: inout Int32, cumpow: inout Float, cumstrength: inout Float, freqnum: inout Double, freqden: inout Double) {
    let putfreq = expf((1.0 / BPEROOVERLOG2) * (Float(histpeak.hindex) + 96.0))

    for j in 0..<npeak {
        let fpnum = Double(peaklist[j].pfreq / putfreq)
        let pnum = Int(fpnum + 0.5)
        let fipnum = Double(pnum)
        var deviation: Double
        if pnum > 16 || pnum < 1 { continue }
        deviation = 1.0 - fpnum / fipnum
        if deviation > -PARTIALDEVIANCE && deviation < PARTIALDEVIANCE {
            var stdev: Double
            var weight: Double
            npartials += 1
            if pnum < 8 { nbelow8 += 1 }
            cumpow += peaklist[j].ppow
            cumstrength += sqrt(sqrt(peaklist[j].ppow))
            stdev = Double(peaklist[j].pwidth) > MINBW ? Double(peaklist[j].pwidth) : MINBW
            weight = 1.0 / (stdev * fipnum) * (stdev * fipnum)
            freqden += weight
            freqnum += weight * Double(peaklist[j].pfreq) / fipnum
        }
    }
}


private func swift_ptrack_pt6(p: inout zt_ptrack, nbelow8: Int, npartials: Int, totalpower: Double, histpeak: inout HISTOPEAK, cumpow: Float, cumstrength: Float, freqnum: Double, freqden: Double, n: Int) {
    if (nbelow8 < 4 || npartials < 7) && cumpow < 0.01 * Float(totalpower) {
        histpeak.hvalue = 0
    } else {
        var pitchpow = cumstrength * cumstrength
        let freqinbins = freqnum / freqden
        pitchpow = pitchpow * pitchpow

        if freqinbins < MINFREQINBINS {
            histpeak.hvalue = 0
        } else {
            let hzperbin = p.sr / Double(n + n)
            let hpitch = hzperbin * freqnum / freqden
            histpeak.hpitch = Float(hpitch)
            p.cps = Double(hpitch)
            histpeak.hloud = DBSCAL * Double(logf(pitchpow / Float(n)))
        }
    }
}

private func swift_ptrack_set_spec(p: inout zt_ptrack) {
    swift_ptrack_set_spec_pt1(p: &p)
    swift_ptrack_set_spec_pt2(p: &p)
    swift_ptrack_set_spec_pt3(p: &p)
    swift_ptrack_set_spec_pt4(p: &p)
}

private func swift_ptrack_set_spec_pt1(p: inout zt_ptrack) {
    let sig = p.signal
    let sinus = p.sin
    let hop = p.hopsize

    for i in 0..<hop {
        let k = i * 2
        p.spec1[Int(k)] = sig[Int(i)] * sinus[Int(k)]
        p.spec1[Int(k) + 1] = sig[Int(i)] * sinus[Int(k) + 1]
    }

    zt_fft_cpx(&p.fft, &p.spec1, Int32(hop))
}

private func swift_ptrack_set_spec_pt2(p: inout zt_ptrack) {
    let hop = p.hopsize
    let n = 2 * hop

    var k = 2 * FLTLEN
    for i in stride(from: 0, to: Int(hop), by: 2) {
        p.spec2[k] = p.spec1[i]
        p.spec2[k + 1] = p.spec1[i + 1]
        k += 4
    }

    k = 2*FLTLEN+2
    for i in stride(from: Int(n) - 2, to: -1, by: -2) {
        p.spec2[k] = p.spec1[i]
        p.spec2[k + 1] = -p.spec1[i + 1]
        k += 4
    }

    k = 2*FLTLEN-2
    for i in stride(from: 2 * FLTLEN, to: FLTLEN * 4, by: 2) {
        p.spec2[k] = p.spec2[i]
        p.spec2[k + 1] = -p.spec2[i + 1]
        k -= 2
    }

    k = 2*FLTLEN+Int(n)
    for i in stride(from: Int(n) - 2, to: -1, by: -2) {
        p.spec2[k] = p.spec2[i]
        p.spec2[k + 1] = -p.spec2[k + 1]
        k += 2
    }
}

private func swift_ptrack_set_spec_pt3(p: inout zt_ptrack) {
    let prev = p.prev
    let hop = p.hopsize
    let halfhop = hop >> 1
    var j = 0
    var k = 2 * FLTLEN

    for _ in 0..<halfhop {
        var re: Float
        var im: Float

        re = COEF1 * (prev[k - 2] - prev[k + 1] + p.spec2[k - 2] - prev[k + 1]) +
             COEF2 * (prev[k - 3] - prev[k + 2] + p.spec2[k - 3] - p.spec2[2]) +
             COEF3 * (-prev[k - 6] + prev[k + 5] - p.spec2[k - 6] + p.spec2[k + 5]) +
             COEF4 * (-prev[k - 7] + prev[k + 6] - p.spec2[k - 7] + p.spec2[k + 6]) +
             COEF5 * (prev[k - 10] - prev[k + 9] + p.spec2[k - 10] - p.spec2[k + 9])

        im = COEF1 * (prev[k - 1] + prev[k] + p.spec2[k - 1] + p.spec2[k]) +
             COEF2 * (-prev[k - 4] - prev[k + 3] - p.spec2[k - 4] - p.spec2[k + 3]) +
             COEF3 * (-prev[k - 5] - prev[k + 4] - p.spec2[k - 5] - p.spec2[k + 4]) +
             COEF4 * (prev[k - 8] + prev[k + 7] + p.spec2[k - 8] + p.spec2[k + 7]) +
             COEF5 * (prev[k - 9] + prev[k + 8] + p.spec2[k - 9] + p.spec2[k + 8])

        p.spec1[j]     = MAGIC * (re + im)
        p.spec1[j + 1] = MAGIC * (im - re)
        p.spec1[j + 4] = prev[k] + p.spec2[k + 1]
        p.spec1[j + 5] = prev[k + 1] - p.spec2[k]

        j += 8
        k += 2

        re = COEF1 * ( prev[k-2] - prev[k+1]  - p.spec2[k-2] + p.spec2[k+1]) +
             COEF2 * ( prev[k-3] - prev[k+2]  - p.spec2[k-3] + p.spec2[k+2]) +
             COEF3 * (-prev[k-6] + prev[k+5]  + p.spec2[k-6] - p.spec2[k+5]) +
             COEF4 * (-prev[k-7] + prev[k+6]  + p.spec2[k-7] - p.spec2[k+6]) +
             COEF5 * ( prev[k-10] - prev[k+9] - p.spec2[k-10] + p.spec2[k+9])

        im = COEF1 * ( prev[k-1] + prev[k]   - p.spec2[k-1] - p.spec2[k]) +
             COEF2 * (-prev[k-4] - prev[k+3] + p.spec2[k-4] + p.spec2[k+3]) +
             COEF3 * (-prev[k-5] - prev[k+4] + p.spec2[k-5] + p.spec2[k+4]) +
             COEF4 * ( prev[k-8] + prev[k+7] - p.spec2[k-8] - p.spec2[k+7]) +
             COEF5 * ( prev[k-9] + prev[k+8] - p.spec2[k-9] - p.spec2[k+8])

        p.spec1[j]   = MAGIC * (re + im)
        p.spec1[j+1] = MAGIC * (im - re)
        p.spec1[j+4] = prev[k] - p.spec2[k+1]
        p.spec1[j+5] = prev[k+1] + p.spec2[k]

        j += 8
        k += 2
    }
}

private func swift_ptrack_set_spec_pt4(p: inout zt_ptrack) {
    let spectmp = p.spec2
    let hop = p.hopsize
    let n = Int(2 * hop)

    for i in 0..<n + 4 * FLTLEN {
        p.prev[i] = spectmp[i]
    }

    for i in 0..<MINBIN {
        p.spec1[4 * i + 2] = 0
        p.spec1[4 * i + 3] = 0
    }
}
