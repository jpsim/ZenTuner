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

// Since this file was ported from C with many variable names preserved, disable SwiftLint
// swiftlint:disable:next blanket_disable_command
// swiftlint:disable all

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

public struct ZenPTrack {
    fileprivate let size: Double
    fileprivate let numpks: Int
    fileprivate let sr: Double
    fileprivate let sinTable: [Float]
    fileprivate let hopsize: Int
    fileprivate let winsize: Int
    fileprivate var signal: [Float]
    fileprivate var spec1: [Float]
    fileprivate var spec2: [Float]
    fileprivate var prev: [Float]
    fileprivate var peaklist = [Peak]()
    fileprivate var cnt = 0
    fileprivate var histcnt = 0
    fileprivate var cps = 0.0
    fileprivate var dbs = Array(repeating: -144.0, count: 20)
    fileprivate var fft: ZenFFT

    public init(sampleRate: Double, hopSize: Double, peakCount: Int) {
        size = hopSize
        numpks = peakCount
        sr = sampleRate
        hopsize = Int(size)
        winsize = hopsize * 2

        precondition(winsize.isPowerOfTwo)

        let powtwo = Int(log2(Double(winsize)))

        fft = ZenFFT(M: powtwo - 1, size: size)
        signal = Array(repeating: 0, count: hopsize)
        prev = Array(repeating: 0, count: winsize + 4 * FLTLEN)
        spec1 = Array(repeating: 0, count: winsize * 4)
        spec2 = Array(repeating: 0, count: winsize * 4 + 4 * FLTLEN)
        peaklist = Array(repeating: Peak(), count: numpks + 1)

        sinTable = { [hopsize, winsize] in
            Array(unsafeUninitializedCapacity: hopsize * 2) { buffer, initializedCount in
                for i in 0..<hopsize {
                    buffer[2 * i] = cos((.pi * Float(i)) / (Float(winsize)))
                    buffer[2 * i + 1] = -sin((.pi * Float(i)) / (Float(winsize)))
                }
                initializedCount = hopsize * 2
            }
        }()
    }

    public mutating func compute(bufferValue: Float, pitch: inout Double, amplitude: inout Double ) {
        var pos = cnt
        if pos == hopsize {
            run()
            pos = 0
        }

        signal[pos] = bufferValue * 32768.0
        pos += 1

        pitch = cps
        amplitude = exp(dbs[histcnt] / 20.0 * log(10.0))

        cnt = pos
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

private struct HISTOPEAK {
    let hindex: Int
    var hpitch: Double = 0

    init(histogram: [Float]) {
        hindex = histogram.enumerated().max(by: { $0.element < $1.element })?.offset ?? -1
    }
}

private struct Peak {
    let pfreq: Double
    let pwidth: Double
    let ppow: Double
    let ploudness: Double

    init(pfreq: Double = 0, pwidth: Double = 0, ppow: Double = 0, ploudness: Double = 0) {
        self.pfreq = pfreq
        self.pwidth = pwidth
        self.ppow = ppow
        self.ploudness = ploudness
    }
}

private struct PowerTotals {
    var power = 0.0
    var loudness = 0.0
    var db = 0.0
}

private extension ZenPTrack {
    mutating func run() {
        histcnt += 1
        if histcnt == NPREV {
            histcnt = 0
        }
        setSpec()
        let totals = computePowerTotals()
        if totals.db >= MINAMPS {
            ptrack(totals: totals)
        }
    }

    mutating func computePowerTotals() -> PowerTotals {
        var totals = PowerTotals()
        for i in stride(from: 4 * MINBIN, to: (winsize - 2) * 4, by: 4) {
            let re = spec1[i] - 0.5 * (spec1[i - 8] + spec1[i + 8])
            let im = spec1[i + 1] - 0.5 * (spec1[i - 7] + spec1[i + 9])
            let power = re * re + im * im
            spec1[i + 2] = power
            totals.power += Double(power)
            spec1[i + 3] = Float(totals.power)
        }

        if totals.power > 1.0e-9 {
            totals.db = DBSCAL * log(totals.power / Double(winsize))
            totals.loudness = sqrt(sqrt(totals.power))
            totals.db = max(totals.db, 0)
        } else {
            totals.db = 0.0
            totals.loudness = 0.0
        }

        dbs[histcnt] = totals.db + DBOFFSET
        return totals
    }

    mutating func ptrack(totals: PowerTotals) {
        var npeak = 0

        ptrackPt2(
            npeak: &npeak,
            totalpower: totals.power
        )

        let histogram = ptrackPt3(npeak: npeak, totalloudness: totals.loudness)
        var histpeak = HISTOPEAK(histogram: histogram)

        var cumpow = 0.0
        var freqnum = 0.0
        var freqden = 0.0
        var npartials = 0
        var nbelow8 = 0

        ptrackPt5(
            histpeak: histpeak,
            npeak: npeak,
            npartials: &npartials,
            nbelow8: &nbelow8,
            cumpow: &cumpow,
            freqnum: &freqnum,
            freqden: &freqden
        )

        ptrackPt6(
            nbelow8: nbelow8,
            npartials: npartials,
            totalpower: totals.power,
            histpeak: &histpeak,
            cumpow: cumpow,
            freqnum: freqnum,
            freqden: freqden
        )
    }

    mutating func ptrackPt2(npeak: inout Int, totalpower: Double) {
        let spec = spec1
        for i in stride(from: 4 * MINBIN, to: 4 * (winsize - 2), by: 4) {
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

            peaklist[npeak] = Peak(
                pfreq: Double(totalfreq),
                pwidth: Double(stdev),
                ppow: Double(height),
                ploudness: sqrt(sqrt(Double(height)))
            )
            npeak += 1
        }
    }

    mutating func ptrackPt3(npeak: Int, totalloudness: Double) -> [Float] {
        let histogram = spec2
            .withUnsafeMutableBufferPointer { $0.baseAddress!.advanced(by: BINGUARD) }
        let maxbin = BINPEROCT * (Int(log2(Double(winsize))) - 2)

        for i in 0..<Int(maxbin) { histogram[i] = 0 }

        for peak in peaklist.prefix(npeak) {
            let pit = BPEROOVERLOG2 * log(peak.pfreq) - 96
            let binbandwidth = FACTORTOBINS * peak.pwidth / peak.pfreq
            let putbandwidth = binbandwidth < 2 ? 2 : binbandwidth
            let weightbandwidth = binbandwidth < 1 ? 1 : binbandwidth
            let weightamp = 4 * peak.ploudness / totalloudness

            for (index, onset) in partialonset.enumerated() {
                let bin = pit - onset
                guard bin < Double(maxbin) else { continue }
                let firstbin = Int(bin + 0.5 - 0.5 * putbandwidth)
                if (firstbin < -BINGUARD) {
                    continue
                }

                let score = Float(30 * weightamp / (Double(index + 7) * weightbandwidth))
                let lastbin = Int(bin + 0.5 + (0.5 * putbandwidth))
                let ibw = lastbin - firstbin
                let para = Float(1 / (putbandwidth * putbandwidth))
                var pphase = Float(firstbin) - Float(bin)
                for k in 0...ibw {
                    histogram[k + firstbin] += score * (1 - para * pphase * pphase)
                    pphase += 1
                }
            }
        }

        return Array(UnsafeBufferPointer(start: histogram, count: maxbin))
    }

    func ptrackPt5(histpeak: HISTOPEAK, npeak: Int, npartials: inout Int, nbelow8: inout Int, cumpow: inout Double, freqnum: inout Double, freqden: inout Double) {
        let putfreq = exp((1.0 / BPEROOVERLOG2) * (Double(histpeak.hindex) + 96.0))

        for peak in peaklist.prefix(npeak) {
            let fpnum = peak.pfreq / putfreq
            let pnum = Int(fpnum + 0.5)

            if pnum > 16 || pnum < 1 { continue }

            let fipnum = Double(pnum)
            let deviation = 1.0 - fpnum / fipnum

            guard abs(deviation) < PARTIALDEVIANCE else {
                continue
            }

            npartials += 1
            if pnum < 8 { nbelow8 += 1 }
            cumpow += peak.ppow
            let stdev = peak.pwidth > MINBW ? peak.pwidth : MINBW
            let weight = 1.0 / pow(stdev * fipnum, 2)
            freqden += weight
            freqnum += weight * peak.pfreq / fipnum
        }
    }

    mutating func ptrackPt6(nbelow8: Int, npartials: Int, totalpower: Double, histpeak: inout HISTOPEAK, cumpow: Double, freqnum: Double, freqden: Double) {
        if (nbelow8 < 4 || npartials < 7) && cumpow < 0.01 * totalpower {
            return
        }

        let freqinbins = freqnum / freqden

        if freqinbins < MINFREQINBINS {
            return
        }

        let hzperbin = sr / Double(winsize + winsize)
        histpeak.hpitch = hzperbin * freqnum / freqden
        cps = histpeak.hpitch
    }

    mutating func setSpec() {
        setSpecPt1()
        setSpecPt2()
        setSpecPt3()
        setSpecPt4()
    }

    mutating func setSpecPt1() {
        for i in 0..<hopsize {
            let k = i * 2
            spec1[k] = signal[i] * sinTable[k]
            spec1[k + 1] = signal[i] * sinTable[k + 1]
        }

        fft.compute(buf: &spec1)
    }

    mutating func setSpecPt2() {
        var k = 2 * FLTLEN
        for i in stride(from: 0, to: hopsize, by: 2) {
            spec2[k] = spec1[i]
            spec2[k + 1] = spec1[i + 1]
            k += 4
        }

        k = 2 * FLTLEN + 2
        for i in stride(from: winsize - 2, to: -1, by: -2) {
            spec2[k] = spec1[i]
            spec2[k + 1] = -spec1[i + 1]
            k += 4
        }

        k = 2 * FLTLEN - 2
        for i in stride(from: 2 * FLTLEN, to: FLTLEN * 4, by: 2) {
            spec2[k] = spec2[i]
            spec2[k + 1] = -spec2[i + 1]
            k -= 2
        }

        k = 2 * FLTLEN + winsize
        for i in stride(from: winsize - 2, to: -1, by: -2) {
            spec2[k] = spec2[i]
            spec2[k + 1] = -spec2[k + 1]
            k += 2
        }
    }

    mutating func setSpecPt3() {
        let halfhop = hopsize >> 1
        var j = 0
        var k = 2 * FLTLEN

        for _ in 0..<halfhop {
            var re: Float
            var im: Float

            re = COEF1 * ( prev[k - 2] - prev[k + 1] + spec2[k - 2] - prev[k + 1]) +
                 COEF2 * ( prev[k - 3] - prev[k + 2] + spec2[k - 3] - spec2[2]) +
                 COEF3 * (-prev[k - 6] + prev[k + 5] - spec2[k - 6] + spec2[k + 5]) +
                 COEF4 * (-prev[k - 7] + prev[k + 6] - spec2[k - 7] + spec2[k + 6]) +
                 COEF5 * ( prev[k - 10] - prev[k + 9] + spec2[k - 10] - spec2[k + 9])

            im = COEF1 * ( prev[k - 1] + prev[k] + spec2[k - 1] + spec2[k]) +
                 COEF2 * (-prev[k - 4] - prev[k + 3] - spec2[k - 4] - spec2[k + 3]) +
                 COEF3 * (-prev[k - 5] - prev[k + 4] - spec2[k - 5] - spec2[k + 4]) +
                 COEF4 * ( prev[k - 8] + prev[k + 7] + spec2[k - 8] + spec2[k + 7]) +
                 COEF5 * ( prev[k - 9] + prev[k + 8] + spec2[k - 9] + spec2[k + 8])

            spec1[j]     = HALF_SQRT_TWO * (re + im)
            spec1[j + 1] = HALF_SQRT_TWO * (im - re)
            spec1[j + 4] = prev[k] + spec2[k + 1]
            spec1[j + 5] = prev[k + 1] - spec2[k]

            j += 8
            k += 2

            re = COEF1 * ( prev[k - 2] - prev[k + 1] - spec2[k - 2] + spec2[k + 1]) +
                 COEF2 * ( prev[k - 3] - prev[k + 2] - spec2[k - 3] + spec2[k + 2]) +
                 COEF3 * (-prev[k - 6] + prev[k + 5] + spec2[k - 6] - spec2[k + 5]) +
                 COEF4 * (-prev[k - 7] + prev[k + 6] + spec2[k - 7] - spec2[k + 6]) +
                 COEF5 * ( prev[k - 10] - prev[k + 9] - spec2[k - 10] + spec2[k + 9])

            im = COEF1 * ( prev[k - 1] + prev[k] - spec2[k - 1] - spec2[k]) +
                 COEF2 * (-prev[k - 4] - prev[k + 3] + spec2[k - 4] + spec2[k + 3]) +
                 COEF3 * (-prev[k - 5] - prev[k + 4] + spec2[k - 5] + spec2[k + 4]) +
                 COEF4 * ( prev[k - 8] + prev[k + 7] - spec2[k - 8] - spec2[k + 7]) +
                 COEF5 * ( prev[k - 9] + prev[k + 8] - spec2[k - 9] - spec2[k + 8])

            spec1[j]     = HALF_SQRT_TWO * (re + im)
            spec1[j + 1] = HALF_SQRT_TWO * (im - re)
            spec1[j + 4] = prev[k] - spec2[k + 1]
            spec1[j + 5] = prev[k + 1] + spec2[k]

            j += 8
            k += 2
        }
    }

    mutating func setSpecPt4() {
        for i in 0..<winsize + 4 * FLTLEN {
            prev[i] = spec2[i]
        }

        for i in 0..<MINBIN {
            spec1[4 * i + 2] = 0
            spec1[4 * i + 3] = 0
        }
    }
}

private extension BinaryInteger {
    var isPowerOfTwo: Bool {
        return (self > 0) && (self & (self - 1) == 0)
    }
}
