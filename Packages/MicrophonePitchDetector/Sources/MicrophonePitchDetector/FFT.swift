/*
 * FFT library
 * based on public domain code by John Green <green_jt@vsdec.npt.nuwc.navy.mil>
 * original version is available at
 *   http://hyperarchive.lcs.mit.edu/
 *         /HyperArchive/Archive/dev/src/ffts-for-risc-2-c.hqx
 * ported to Csound by Istvan Varga, 2005
 * ported to Swift by JP Simard, 2022
 */

import CMicrophonePitchDetector
import Darwin

private let MCACHE: Int = 11 - (MemoryLayout<Float>.size / 8)

// Since this file was ported from C with many variable names preserved, disable SwiftLint
// swiftlint:disable identifier_name

// MARK: - Init

func swift_zt_fft_init(M: Int) -> ZTFFT {
    let utbl = UnsafeMutablePointer<Float>.allocate(capacity: (pow2(M) / 4 + 1))
    swiftfftCosInit(M: M, Utbl: utbl)

    let BRLowCpx = UnsafeMutablePointer<Int16>.allocate(capacity: pow2(M / 2 - 1))
    swiftfftBRInit(M: M, BRLow: BRLowCpx)

    let BRLow = UnsafeMutablePointer<Int16>.allocate(capacity: pow2((M - 1) / 2 - 1))
    swiftfftBRInit(M: M - 1, BRLow: BRLow)
    return ZTFFT(
        utbl: utbl,
        BRLow: BRLow,
        BRLowCpx: BRLowCpx
    )
}

// MARK: - Compute

final class ZTFFT {
    let utbl: UnsafeMutablePointer<Float>!
    let BRLow: UnsafeMutablePointer<Int16>!
    let BRLowCpx: UnsafeMutablePointer<Int16>!

    init(utbl: UnsafeMutablePointer<Float>? = nil, BRLow: UnsafeMutablePointer<Int16>? = nil, BRLowCpx: UnsafeMutablePointer<Int16>? = nil) {
        self.utbl = utbl
        self.BRLow = BRLow
        self.BRLowCpx = BRLowCpx
    }
}

func zt_fft_cpx(fft: inout ZTFFT, buf: UnsafeMutablePointer<Float>?, FFTsize: Int, sqrttwo: Float) {
    swift_ffts1(ioptr: buf, M: Int32(log2(Double(FFTsize))), Utbl: fft.utbl, BRLow: fft.BRLowCpx, sqrttwo: sqrttwo)
}

// MARK: - Private Compute

private func swift_ffts1(ioptr: UnsafeMutablePointer<Float>?, M: Int32, Utbl: UnsafeMutablePointer<Float>?, BRLow: UnsafeMutablePointer<Int16>?, sqrttwo: Float) {
    var StageCnt: Int32
    var NDiffU: Int32

    bitrevR2(ioptr, M, BRLow)
    StageCnt = (M - 1) / 3
    NDiffU = 2
    if (M - 1 - (StageCnt * 3)) == 1 {
        bfR2(ioptr, M, NDiffU)
        NDiffU *= 2
    }
    if (M - 1 - (StageCnt * 3)) == 2 {
        bfR4(ioptr, M, NDiffU, sqrttwo)
        NDiffU *= 4
    }
    if M <= MCACHE {
        bfstages(ioptr, M, Utbl, 1, NDiffU, StageCnt)
    } else {
        fftrecurs(ioptr, M, Utbl, 1, NDiffU, StageCnt)
    }
}


// MARK: - FFT Tables

private func swiftfftCosInit(M: Int, Utbl: UnsafeMutablePointer<Float>) {
    let fftN = pow2(M)
    Utbl[0] = 1.0
    for i in 1..<fftN / 4 {
        Utbl[i] = cos(2.0 * Float.pi * Float(i) / Float(fftN))
    }
    Utbl[fftN / 4] = 0.0
}

private func swiftfftBRInit(M: Int, BRLow: UnsafeMutablePointer<Int16>) {
    let Mroot_1 = M / 2 - 1
    let Nroot_1 = pow2(Mroot_1)
    for i in 0..<Nroot_1 {
        var bitsum = 0
        var bitmask = 1
        for bit in 1...Mroot_1 {
            if i & bitmask != 0 {
                bitsum += Nroot_1 >> bit
            }
            bitmask <<= 1
        }
        BRLow[i] = Int16(bitsum)
    }
}

private func pow2(_ n: Int) -> Int {
    1 << n
}
