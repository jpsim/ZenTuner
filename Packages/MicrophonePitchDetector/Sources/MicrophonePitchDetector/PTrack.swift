/*
 * PTrack
 *
 * This code has been extracted from the Csound opcode "ptrack".
 * It was rewritten in Swift by JP Simard for use in Zen Tuner.
 *
 * Original Author(s): Victor Lazzarini, Miller Puckette (Original Algorithm), Aurelius Prochazka
 * Year: 2007
 * Location: Opcodes/pitchtrack.c
 *
 */

import Darwin

enum PTrackError: Error {
    case invalidWindowSize
}

// Since this file was ported from C with many variable names preserved, disable SwiftLint
// swiftlint:disable file_length function_body_length function_parameter_count
// swiftlint:disable identifier_name line_length type_name

private let MINFREQINBINS = 5.0
private let NPREV = 20
private let MINBW = 0.03
private let BINPEROCT = 48
private let BPEROOVERLOG2 = 69.24936196
private let FACTORTOBINS = 4 / 0.0145453
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
private let HALF_SQRT_TWO = sqrtf(2) / 2

struct zt_ptrack {
    fileprivate let size: Double
    fileprivate let numpks: Int
    fileprivate let sr: Double
    fileprivate let sin: [Float]
    fileprivate let hopsize: Int
    fileprivate var signal: [Float]
    fileprivate var prev: [Float]
    fileprivate var spec1: [Float]
    fileprivate var spec2: [Float]
    fileprivate var peaklist = [Peak]()
    fileprivate var cnt = 0
    fileprivate var histcnt = 0
    fileprivate var cps = 0.0
    fileprivate var dbs = Array(repeating: -144.0, count: 20)
    fileprivate var fft: ZTFFT

    init(sampleRate: Double, hopSize: Double, peakCount: Int) throws {
        size = hopSize
        numpks = peakCount
        sr = sampleRate
        hopsize = Int(size)

        let winsize = hopsize * 2
        var powtwo = -1
        var tmp = winsize

        while tmp > 0 {
            tmp >>= 1
            powtwo += 1
        }

        fft = ZTFFT(M: powtwo - 1, size: hopsize)

        if winsize != (1 << powtwo) {
            throw PTrackError.invalidWindowSize
        }

        signal = Array(repeating: 0, count: hopsize)
        prev = Array(repeating: 0, count: winsize + 4 * FLTLEN)
        spec1 = Array(repeating: 0, count: winsize * 4)
        spec2 = Array(repeating: 0, count: winsize * 4 + 4 * FLTLEN)
        peaklist = Array(repeating: Peak(), count: numpks + 1)

        var tmpsin: [Float] = Array(repeating: 0, count: hopsize * 2)
        for i in 0..<hopsize {
            tmpsin[2 * i] = cos((.pi * Float(i)) / (Float(winsize)))
            tmpsin[2 * i + 1] = -Darwin.sin((.pi * Float(i)) / (Float(winsize)))
        }

        sin = tmpsin
    }
}

private let partialonset = [
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
    192.0
]

func swift_zt_ptrack_compute(
    _ p: inout zt_ptrack,
    _ in: UnsafeMutablePointer<Float>,
    _ freq: inout Double,
    _ amp: inout Double
) {
    var pos = p.cnt
    if pos == p.hopsize {
        ptrackSwift(p: &p)
        pos = 0
    }

    p.signal[pos] = `in`.pointee * 32768.0
    pos += 1

    freq = p.cps
    amp = exp(p.dbs[p.histcnt] / 20.0 * log(10.0))

    p.cnt = pos
}

private func ptrackSwift(p: inout zt_ptrack) {
    let n = 2 * p.hopsize
    swift_ptrack_set_histcnt(p: &p, n: n)
    swift_ptrack_set_spec(p: &p)

    var totalpower = 0.0
    var totalloudness = 0.0
    var totaldb = 0.0
    swift_ptrack_set_totals(p: &p, totalpower: &totalpower, totalloudness: &totalloudness, totaldb: &totaldb, n: n)

    guard totaldb >= MINAMPS else {
        return
    }

    ptrack(
        p: &p,
        n: n,
        totalpower: totalpower,
        totalloudness: totalloudness,
        maxbin: swift_ptrack_get_maxbin(n: n),
        numpks: p.numpks
    )
}

private func swift_ptrack_set_histcnt(p: inout zt_ptrack, n: Int) {
    var count = p.histcnt + 1
    if count == NPREV { count = 0 }
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
        totaldb = DBSCAL * log(totalpower / Double(n))
        totalloudness = sqrt(sqrt(totalpower))
        totaldb = max(totaldb, 0)
    } else {
        totaldb = 0.0
        totalloudness = 0.0
    }

    p.dbs[p.histcnt] = totaldb + DBOFFSET
}

private func swift_ptrack_get_maxbin(n: Int) -> Double {
    var tmp = n, logn = -1
    while tmp > 0 {
        tmp &>>= 1
        logn += 1
    }
    return Double(BINPEROCT * (logn - 2))
}

private struct HISTOPEAK {
    var hvalue: Float = 0.0
    var hpitch = 0.0
    var hloud = 0.0
    var hindex = 0
}

private func ptrack(p: inout zt_ptrack, n: Int, totalpower: Double, totalloudness: Double, maxbin: Double, numpks: Int) {
    func getHist(spectmp: UnsafeMutablePointer<Float>) -> UnsafeMutablePointer<Float> {
        return spectmp.advanced(by: BINGUARD)
    }

    let histogram = getHist(spectmp: &p.spec2)
    var npeak = 0

    swift_ptrack_pt2(
        npeak: &npeak,
        numpks: Int(numpks),
        peaklist: &p.peaklist,
        totalpower: totalpower,
        spec: &p.spec1,
        n: n
    )

    swift_ptrack_pt3(
        npeak: &npeak,
        numpks: numpks,
        peaklist: &p.peaklist,
        maxbin: maxbin,
        histogram: histogram,
        totalloudness: totalloudness
    )

    var histpeak = HISTOPEAK()

    swift_ptrack_pt4(histpeak: &histpeak, maxbin: maxbin, histogram: histogram)

    var cumpow = 0.0
    var cumstrength = 0.0
    var freqnum = 0.0
    var freqden = 0.0
    var npartials = 0
    var nbelow8 = 0

    swift_ptrack_pt5(
        histpeak: histpeak,
        npeak: npeak,
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
        nbelow8: nbelow8,
        npartials: npartials,
        totalpower: totalpower,
        histpeak: &histpeak,
        cumpow: cumpow,
        cumstrength: cumstrength,
        freqnum: freqnum,
        freqden: freqden,
        n: n
    )
}

private struct Peak {
    var pfreq = 0.0
    var pwidth = 0.0
    var ppow = 0.0
    var ploudness = 0.0
}

private func swift_ptrack_pt2(npeak: inout Int, numpks: Int, peaklist: UnsafeMutablePointer<Peak>, totalpower: Double, spec: UnsafeMutablePointer<Float>, n: Int) {
    for i in stride(from: 4 * MINBIN, to: 4 * (n - 2), by: 4) {
        if npeak >= numpks { break }
        let height = spec[i + 2], h1 = spec[i - 2], h2 = spec[i + 6]
        var totalfreq, peakfr, tmpfr1, tmpfr2, m, `var`, stdev: Float

        if height < h1 || height < h2 || h1 < 0.00001 * Float(totalpower) || h2 < 0.00001 * Float(totalpower) { continue }

        peakfr = ((spec[i - 8] - spec[i + 8]) * (2.0 * spec[i] - spec[i + 8] - spec[i - 8]) +
                  (spec[i - 7] - spec[i + 9]) * (2.0 * spec[i + 1] - spec[i + 9] - spec[i - 7])) / (height + height)
        tmpfr1 = ((spec[i - 12] - spec[i + 4]) * (2.0 * spec[i - 4] - spec[i + 4] - spec[i - 12]) +
                  (spec[i - 11] - spec[i + 5]) * (2.0 * spec[i - 3] - spec[i + 5] - spec[i - 11])) / (2.0 * h1) - 1
        tmpfr2 = ((spec[i - 4] - spec[i + 12]) * (2.0 * spec[i + 4] - spec[i + 12] - spec[i - 4]) +
                  (spec[i - 3] - spec[i + 13]) * (2.0 * spec[i + 5] - spec[i + 13] - spec[i - 3])) / (2.0 * h2) + 1

        m = (peakfr + tmpfr1 + tmpfr2) / 3
        `var` = ((peakfr - m) * (peakfr - m) + (tmpfr1 - m) * (tmpfr1 - m) + (tmpfr2 - m) * (tmpfr2 - m)) / 2

        totalfreq = Float(i >> 2) + m
        if `var` * Float(totalpower) > THRSH * height || `var` < 1.0e-30 {
            continue
        }

        stdev = sqrtf(`var`)
        totalfreq = max(totalfreq, 4)

        peaklist[npeak].pwidth = Double(stdev)
        peaklist[npeak].ppow = Double(height)
        peaklist[npeak].ploudness = sqrt(sqrt(Double(height)))
        peaklist[npeak].pfreq = Double(totalfreq)
        npeak += 1
    }
}

private func swift_ptrack_pt3(npeak: inout Int, numpks: Int, peaklist: UnsafeMutablePointer<Peak>, maxbin: Double, histogram: UnsafeMutablePointer<Float>, totalloudness: Double) {
    if npeak > numpks { npeak = numpks }

    for i in 0..<Int(maxbin) { histogram[i] = 0 }

    for i in 0..<npeak {
        let pit = BPEROOVERLOG2 * log(peaklist[i].pfreq) - 96
        let binbandwidth = FACTORTOBINS * peaklist[i].pwidth / peaklist[i].pfreq
        let putbandwidth = binbandwidth < 2 ? 2 : binbandwidth
        let weightbandwidth = binbandwidth < 1 ? 1 : binbandwidth
        let weightamp = 4 * peaklist[i].ploudness / totalloudness
        for j in 0..<partialonset.count {
            let bin = pit - partialonset[j]
            guard bin < maxbin else { continue }

            let score = 30 * weightamp / (Double(j + 7) * weightbandwidth)
            let firstbin = bin + 0.5 - 0.5 * putbandwidth
            let lastbin = bin + 0.5 + 0.5 * putbandwidth
            let ibw = lastbin - firstbin
            if firstbin < -Double(BINGUARD) { break }
            let para = 1 / (putbandwidth * putbandwidth)
            var pphase = firstbin - bin
            for k in 0...Int(ibw) {
                histogram[k + Int(firstbin)] += Float(score * (1 - para * (pphase + Double(k)) * (pphase + Double(k))))
                pphase += 1
            }
        }
    }
}

private func swift_ptrack_pt4(histpeak: inout HISTOPEAK, maxbin: Double, histogram: UnsafeMutablePointer<Float>) {
    var best: Float = 0
    var indx = -1
    for j in 0..<Int(maxbin) where histogram[j] > best {
        indx = j
        best = histogram[j]
    }

    histpeak.hvalue = best
    histpeak.hindex = indx
}

private func swift_ptrack_pt5(histpeak: HISTOPEAK, npeak: Int, peaklist: UnsafeMutablePointer<Peak>, npartials: inout Int, nbelow8: inout Int, cumpow: inout Double, cumstrength: inout Double, freqnum: inout Double, freqden: inout Double) {
    let putfreq = exp((1.0 / BPEROOVERLOG2) * (Double(histpeak.hindex) + 96.0))

    for j in 0..<npeak {
        let fpnum = peaklist[j].pfreq / putfreq
        let pnum = Int(fpnum + 0.5)

        if pnum > 16 || pnum < 1 { continue }

        let fipnum = Double(pnum)
        let deviation = 1.0 - fpnum / fipnum

        guard deviation > -PARTIALDEVIANCE && deviation < PARTIALDEVIANCE else {
            continue
        }

        var stdev: Double
        var weight: Double
        npartials += 1
        if pnum < 8 { nbelow8 += 1 }
        cumpow += peaklist[j].ppow
        cumstrength += sqrt(sqrt(peaklist[j].ppow))
        stdev = peaklist[j].pwidth > MINBW ? peaklist[j].pwidth : MINBW
        weight = 1.0 / (stdev * fipnum) * (stdev * fipnum)
        freqden += weight
        freqnum += weight * peaklist[j].pfreq / fipnum
    }
}

private func swift_ptrack_pt6(p: inout zt_ptrack, nbelow8: Int, npartials: Int, totalpower: Double, histpeak: inout HISTOPEAK, cumpow: Double, cumstrength: Double, freqnum: Double, freqden: Double, n: Int) {
    if (nbelow8 < 4 || npartials < 7) && cumpow < 0.01 * totalpower {
        histpeak.hvalue = 0
        return
    }

    let freqinbins = freqnum / freqden

    if freqinbins < MINFREQINBINS {
        histpeak.hvalue = 0
        return
    }

    let hzperbin = p.sr / Double(n + n)
    let hpitch = hzperbin * freqnum / freqden
    histpeak.hpitch = hpitch
    p.cps = hpitch
    let pitchpow = pow(cumstrength, 4)
    histpeak.hloud = DBSCAL * log(pitchpow / Double(n))
}

private func swift_ptrack_set_spec(p: inout zt_ptrack) {
    let sig = p.signal
    let sinus = p.sin
    let hop = p.hopsize
    let n = 2 * hop

    for i in 0..<hop {
        let k = i * 2
        p.spec1[k] = sig[i] * sinus[k]
        p.spec1[k + 1] = sig[i] * sinus[k + 1]
    }

    p.fft.compute(buf: &p.spec1)

    var k = 2 * FLTLEN
    for i in stride(from: 0, to: hop, by: 2) {
        p.spec2[k] = p.spec1[i]
        p.spec2[k + 1] = p.spec1[i + 1]
        k += 4
    }

    k = 2 * FLTLEN + 2
    for i in stride(from: n - 2, to: -1, by: -2) {
        p.spec2[k] = p.spec1[i]
        p.spec2[k + 1] = -p.spec1[i + 1]
        k += 4
    }

    k = 2 * FLTLEN - 2
    for i in stride(from: 2 * FLTLEN, to: FLTLEN * 4, by: 2) {
        p.spec2[k] = p.spec2[i]
        p.spec2[k + 1] = -p.spec2[i + 1]
        k -= 2
    }

    k = 2 * FLTLEN + n
    for i in stride(from: n - 2, to: -1, by: -2) {
        p.spec2[k] = p.spec2[i]
        p.spec2[k + 1] = -p.spec2[k + 1]
        k += 2
    }

    let prev = p.prev
    let halfhop = hop >> 1
    var j = 0
    k = 2 * FLTLEN

    for _ in 0..<halfhop {
        var re: Float
        var im: Float

        re = COEF1 * ( prev[k - 2] - prev[k + 1] + p.spec2[k - 2] - prev[k + 1]) +
             COEF2 * ( prev[k - 3] - prev[k + 2] + p.spec2[k - 3] - p.spec2[2]) +
             COEF3 * (-prev[k - 6] + prev[k + 5] - p.spec2[k - 6] + p.spec2[k + 5]) +
             COEF4 * (-prev[k - 7] + prev[k + 6] - p.spec2[k - 7] + p.spec2[k + 6]) +
             COEF5 * ( prev[k - 10] - prev[k + 9] + p.spec2[k - 10] - p.spec2[k + 9])

        im = COEF1 * ( prev[k - 1] + prev[k] + p.spec2[k - 1] + p.spec2[k]) +
             COEF2 * (-prev[k - 4] - prev[k + 3] - p.spec2[k - 4] - p.spec2[k + 3]) +
             COEF3 * (-prev[k - 5] - prev[k + 4] - p.spec2[k - 5] - p.spec2[k + 4]) +
             COEF4 * ( prev[k - 8] + prev[k + 7] + p.spec2[k - 8] + p.spec2[k + 7]) +
             COEF5 * ( prev[k - 9] + prev[k + 8] + p.spec2[k - 9] + p.spec2[k + 8])

        p.spec1[j]     = HALF_SQRT_TWO * (re + im)
        p.spec1[j + 1] = HALF_SQRT_TWO * (im - re)
        p.spec1[j + 4] = prev[k] + p.spec2[k + 1]
        p.spec1[j + 5] = prev[k + 1] - p.spec2[k]

        j += 8
        k += 2

        re = COEF1 * ( prev[k - 2] - prev[k + 1] - p.spec2[k - 2] + p.spec2[k + 1]) +
             COEF2 * ( prev[k - 3] - prev[k + 2] - p.spec2[k - 3] + p.spec2[k + 2]) +
             COEF3 * (-prev[k - 6] + prev[k + 5] + p.spec2[k - 6] - p.spec2[k + 5]) +
             COEF4 * (-prev[k - 7] + prev[k + 6] + p.spec2[k - 7] - p.spec2[k + 6]) +
             COEF5 * ( prev[k - 10] - prev[k + 9] - p.spec2[k - 10] + p.spec2[k + 9])

        im = COEF1 * ( prev[k - 1] + prev[k] - p.spec2[k - 1] - p.spec2[k]) +
             COEF2 * (-prev[k - 4] - prev[k + 3] + p.spec2[k - 4] + p.spec2[k + 3]) +
             COEF3 * (-prev[k - 5] - prev[k + 4] + p.spec2[k - 5] + p.spec2[k + 4]) +
             COEF4 * ( prev[k - 8] + prev[k + 7] - p.spec2[k - 8] - p.spec2[k + 7]) +
             COEF5 * ( prev[k - 9] + prev[k + 8] - p.spec2[k - 9] - p.spec2[k + 8])

        p.spec1[j]     = HALF_SQRT_TWO * (re + im)
        p.spec1[j + 1] = HALF_SQRT_TWO * (im - re)
        p.spec1[j + 4] = prev[k] - p.spec2[k + 1]
        p.spec1[j + 5] = prev[k + 1] + p.spec2[k]

        j += 8
        k += 2
    }

    for i in 0..<n + 4 * FLTLEN {
        p.prev[i] = p.spec2[i]
    }

    for i in 0..<MINBIN {
        p.spec1[4 * i + 2] = 0
        p.spec1[4 * i + 3] = 0
    }
}
