/*
 * FFT library
 * based on public domain code by John Green <green_jt@vsdec.npt.nuwc.navy.mil>
 * original version is available at
 *   http://hyperarchive.lcs.mit.edu/
 *         /HyperArchive/Archive/dev/src/ffts-for-risc-2-c.hqx
 * ported to Csound by Istvan Varga, 2005
 * ported to Swift by JP Simard, 2022
 */

import Darwin

private let SQRT_TWO = sqrtf(2)
private let MCACHE = 11 - (MemoryLayout<Float>.size / 8)

// Since this file was ported from C with many variable names preserved, disable SwiftLint
// swiftlint:disable identifier_name file_length function_body_length
// swiftlint:disable function_parameter_count line_length shorthand_operator

// MARK: - API

final class ZTFFT {
    private let utbl: UnsafeMutablePointer<Float>
    private let BRLow: UnsafeMutablePointer<Int16>
    private let BRLowCpx: UnsafeMutablePointer<Int16>
    private let innerM: Int32

    init(M: Int, size: Int) {
        innerM = Int32(log2(Double(size)))

        utbl = UnsafeMutablePointer<Float>.allocate(capacity: (pow2(M) / 4 + 1))
        swiftfftCosInit(M: M, Utbl: utbl)

        BRLowCpx = UnsafeMutablePointer<Int16>.allocate(capacity: pow2(M / 2 - 1))
        swiftfftBRInit(M: M, BRLow: BRLowCpx)

        BRLow = UnsafeMutablePointer<Int16>.allocate(capacity: pow2((M - 1) / 2 - 1))
        swiftfftBRInit(M: M - 1, BRLow: BRLow)
    }

    func compute(buf: UnsafeMutablePointer<Float>) {
        swift_ffts1(ioptr: buf, M: innerM, Utbl: utbl, BRLow: BRLowCpx)
    }
}

// MARK: - Private Compute

private func swift_ffts1(ioptr: UnsafeMutablePointer<Float>, M: Int32, Utbl: UnsafeMutablePointer<Float>, BRLow: UnsafeMutablePointer<Int16>) {
    var StageCnt: Int32
    var NDiffU: Int32

    swift_bitrevR2(ioptr, M, BRLow)
    StageCnt = (M - 1) / 3
    NDiffU = 2
    if (M - 1 - (StageCnt * 3)) == 1 {
        swift_bfR2(ioptr, M, NDiffU)
        NDiffU *= 2
    }
    if (M - 1 - (StageCnt * 3)) == 2 {
        swift_bfR4(ioptr, Int(M), Int(NDiffU), SQRT_TWO)
        NDiffU *= 4
    }
    if M <= MCACHE {
        swift_bfstages(ioptr, M, Utbl, 1, NDiffU, StageCnt)
    } else {
        swift_fftrecurs(ioptr: ioptr, M: M, Utbl: Utbl, Ustride: 1, NDiffU: NDiffU, StageCnt: StageCnt)
    }
}

private func swift_fftrecurs(ioptr: UnsafeMutablePointer<Float>, M: Int32, Utbl: UnsafeMutablePointer<Float>, Ustride: Int32, NDiffU: Int32, StageCnt: Int32) {
    if M <= MCACHE {
        swift_bfstages(ioptr, M, Utbl, Ustride, NDiffU, StageCnt)
    } else {
        for i1 in 0..<8 {
            swift_fftrecurs(ioptr: ioptr + i1 * Int(pow(2.0, Double(M - 3))) * 2, M: M - 3, Utbl: Utbl, Ustride: 8 * Ustride, NDiffU: NDiffU, StageCnt: StageCnt - 1)
        }
        swift_bfstages(ioptr, M, Utbl, Ustride, Int32(pow(2.0, Double(M - 3))), 1)
    }
}

private func swift_bfR2(_ ioptr: UnsafeMutablePointer<Float>, _ M: Int32, _ NDiffU: Int32) {
    let pos = 2
    let posi = pos + 1
    let pinc = NDiffU * 2
    let pnext = pinc * 4
    let NSameU = Int(pow(2.0, Double(M))) / 4 / Int(NDiffU)
    let pstrt = ioptr
    var p0r = pstrt
    var p1r = pstrt + Int(pinc)
    var p2r = p1r + Int(pinc)
    var p3r = p2r + Int(pinc)

    /* Butterflys           */
    /*
       f0   -       -       f4
       f1   -  1 -  f5
       f2   -       -       f6
       f3   -  1 -  f7
     */
    /* Butterflys           */
    /*
       f0   -       -       f4
       f1   -  1 -  f5
       f2   -       -       f6
       f3   -  1 -  f7
     */

    for _ in 0..<NSameU {
        var f0r = p0r[0]
        var f1r = p1r[0]
        var f0i = p0r[1]
        var f1i = p1r[1]
        var f2r = p2r[0]
        var f3r = p3r[0]
        var f2i = p2r[1]
        var f3i = p3r[1]

        var f4r = f0r + f1r
        var f4i = f0i + f1i
        var f5r = f0r - f1r
        var f5i = f0i - f1i

        var f6r = f2r + f3r
        var f6i = f2i + f3i
        var f7r = f2r - f3r
        var f7i = f2i - f3i

        p0r[0] = f4r
        p0r[1] = f4i
        p1r[0] = f5r
        p1r[1] = f5i
        p2r[0] = f6r
        p2r[1] = f6i
        p3r[0] = f7r
        p3r[1] = f7i

        f0r = p0r[pos]
        f1i = p1r[posi]
        f0i = p0r[posi]
        f1r = p1r[pos]
        f2r = p2r[pos]
        f3i = p3r[posi]
        f2i = p2r[posi]
        f3r = p3r[pos]

        f4r = f0r + f1i
        f4i = f0i - f1r
        f5r = f0r - f1i
        f5i = f0i + f1r

        f6r = f2r + f3i
        f6i = f2i - f3r
        f7r = f2r - f3i
        f7i = f2i + f3r

        p0r[pos] = f4r
        p0r[posi] = f4i
        p1r[pos] = f5r
        p1r[posi] = f5i
        p2r[pos] = f6r
        p2r[posi] = f6i
        p3r[pos] = f7r
        p3r[posi] = f7i

        p0r += Int(pnext)
        p1r += Int(pnext)
        p2r += Int(pnext)
        p3r += Int(pnext)
    }
}

private func swift_bfR4(_ ioptr: UnsafeMutablePointer<Float>, _ M: Int, _ NDiffU: Int, _ sqrttwo: Float) {
    /*** 1 radix 4 stage ***/
    var pos, posi, pinc, pnext, pnexti, NSameU, SameUCnt: Int
    var pstrt, p0r, p1r, p2r, p3r: UnsafeMutablePointer<Float>

    let w1r = 1.0 / sqrttwo    /* cos(pi/4)   */
    var f0r, f0i, f1r, f1i, f2r, f2i, f3r, f3i: Float
    var f4r, f4i, f5r, f5i, f6r, f6i, f7r, f7i: Float
    var t1r, t1i: Float
    let Two: Float = 2.0

    pinc = NDiffU * 2            /* 2 floats per complex */
    pnext = pinc * 4
    pnexti = pnext + 1
    pos = 2
    posi = pos + 1
    NSameU = pow2(M) / 4 / NDiffU        /* 4 pts per butterfly */
    pstrt = ioptr
    p0r = pstrt
    p1r = pstrt + pinc
    p2r = p1r + pinc
    p3r = p2r + pinc

    /* Butterflys           */
    /*
       f0   -       -       f0      -       -       f4
       f1   -  1 -  f5      -       -       f5
       f2   -       -       f6      -  1 -  f6
       f3   -  1 -  f3      - -i -  f7
     */
    /* Butterflys           */
    /*
       f0   -       -       f4      -       -       f4
       f1   - -i -  t1      -       -       f5
       f2   -       -       f2      - w1 -  f6
       f3   - -i -  f7      - iw1-  f7
     */

    f0r = p0r[0]
    f1r = p1r[0]
    f2r = p2r[0]
    f3r = p3r[0]
    f0i = p0r[1]
    f1i = p1r[1]
    f2i = p2r[1]
    f3i = p3r[1]

    f5r = f0r - f1r
    f5i = f0i - f1i
    f0r = f0r + f1r
    f0i = f0i + f1i

    f6r = f2r + f3r
    f6i = f2i + f3i
    f3r = f2r - f3r
    f3i = f2i - f3i

    SameUCnt = NSameU - 1
    while SameUCnt > 0 {
        f7r = f5r - f3i
        f7i = f5i + f3r
        f5r = f5r + f3i
        f5i = f5i - f3r

        f4r = f0r + f6r
        f4i = f0i + f6i
        f6r = f0r - f6r
        f6i = f0i - f6i

        f2r = p2r[pos]
        f2i = p2r[posi]
        f1r = p1r[pos]
        f1i = p1r[posi]
        f3i = p3r[posi]
        f0r = p0r[pos]
        f3r = p3r[pos]
        f0i = p0r[posi]

        p3r[0] = f7r
        p0r[0] = f4r
        p3r[1] = f7i
        p0r[1] = f4i
        p1r[0] = f5r
        p2r[0] = f6r
        p1r[1] = f5i
        p2r[1] = f6i

        f7r = f2r - f3i
        f7i = f2i + f3r
        f2r = f2r + f3i
        f2i = f2i - f3r

        f4r = f0r + f1i
        f4i = f0i - f1r
        t1r = f0r - f1i
        t1i = f0i + f1r

        f5r = t1r - f7r * w1r + f7i * w1r
        f5i = t1i - f7r * w1r - f7i * w1r
        f7r = t1r * Two - f5r
        f7i = t1i * Two - f5i

        f6r = f4r - f2r * w1r - f2i * w1r
        f6i = f4i + f2r * w1r - f2i * w1r
        f4r = f4r * Two - f6r
        f4i = f4i * Two - f6i

        f3r = p3r[pnext]
        f0r = p0r[pnext]
        f3i = p3r[pnexti]
        f0i = p0r[pnexti]
        f2r = p2r[pnext]
        f2i = p2r[pnexti]
        f1r = p1r[pnext]
        f1i = p1r[pnexti]

        p2r[pos] = f6r
        p1r[pos] = f5r
        p2r[posi] = f6i
        p1r[posi] = f5i
        p3r[pos] = f7r
        p0r[pos] = f4r
        p3r[posi] = f7i
        p0r[posi] = f4i

        f6r = f2r + f3r
        f6i = f2i + f3i
        f3r = f2r - f3r
        f3i = f2i - f3i

        f5r = f0r - f1r
        f5i = f0i - f1i
        f0r = f0r + f1r
        f0i = f0i + f1i

        p3r += pnext
        p0r += pnext
        p1r += pnext
        p2r += pnext

        SameUCnt -= 1
    }

    f7r = f5r - f3i
    f7i = f5i + f3r
    f5r = f5r + f3i
    f5i = f5i - f3r

    f4r = f0r + f6r
    f4i = f0i + f6i
    f6r = f0r - f6r
    f6i = f0i - f6i

    f2r = p2r[pos]
    f2i = p2r[posi]
    f1r = p1r[pos]
    f1i = p1r[posi]
    f3i = p3r[posi]
    f0r = p0r[pos]
    f3r = p3r[pos]
    f0i = p0r[posi]

    p3r[0] = f7r
    p0r[0] = f4r
    p3r[1] = f7i
    p0r[1] = f4i
    p1r[0] = f5r
    p2r[0] = f6r
    p1r[1] = f5i
    p2r[1] = f6i

    f7r = f2r - f3i
    f7i = f2i + f3r
    f2r = f2r + f3i
    f2i = f2i - f3r

    f4r = f0r + f1i
    f4i = f0i - f1r
    t1r = f0r - f1i
    t1i = f0i + f1r

    f5r = t1r - f7r * w1r + f7i * w1r
    f5i = t1i - f7r * w1r - f7i * w1r
    f7r = t1r * Two - f5r
    f7i = t1i * Two - f5i

    f6r = f4r - f2r * w1r - f2i * w1r
    f6i = f4i + f2r * w1r - f2i * w1r
    f4r = f4r * Two - f6r
    f4i = f4i * Two - f6i

    p2r[pos] = f6r
    p1r[pos] = f5r
    p2r[posi] = f6i
    p1r[posi] = f5i
    p3r[pos] = f7r
    p0r[pos] = f4r
    p3r[posi] = f7i
    p0r[posi] = f4i
}

private func swift_bitrevR2(_ ioptr: UnsafeMutablePointer<Float>, _ M: Int32, _ BRLow: UnsafeMutablePointer<Int16>) {
    var f0r, f0i, f1r, f1i, f2r, f2i, f3r, f3i, f4r, f4i, f5r, f5i, f6r, f6i, f7r, f7i, t0r, t0i, t1r, t1i: Float
    var p0r, p1r, IOP, iolimit: UnsafeMutablePointer<Float>
    var iCol: UInt
    var posA, posAi, posB, posBi: Int

    let Nrems2 = UInt(pow2((Int(M) + 3) / 2))
    let Nroot_1_ColInc = UInt(pow2(Int(M))) - Nrems2
    let Nroot_1 = UInt(pow2(Int(M) / 2 - 1) - 1)
    let ColstartShift = UInt((M + 1) / 2 + 1)

    posA = pow2(Int(M))               /* 1/2 of POW2(M) complexes */
    posAi = posA + 1
    posB = posA + 2
    posBi = posB + 1

    iolimit = ioptr + UnsafeMutablePointer<Float>.Stride(Nrems2)
    for ioptr in stride(from: ioptr, to: iolimit, by: pow2(Int(M) / 2 + 1)) {
        for Colstart in (0...Nroot_1).reversed() {
            iCol = Nroot_1
            p0r = ioptr + UnsafeMutablePointer<Float>.Stride(Nroot_1_ColInc) + Int(BRLow[Int(Colstart)]) * 4
            IOP = ioptr + UnsafeMutablePointer<Float>.Stride((Colstart << ColstartShift))
            p1r = IOP + Int(BRLow[Int(iCol)]) * 4
            f0r = p0r[0]
            f0i = p0r[1]
            f1r = p0r[posA]
            f1i = p0r[posAi]
            while iCol > Colstart {
                f2r = p0r[2]
                f2i = p0r[2 + 1]
                f3r = p0r[posB]
                f3i = p0r[posBi]
                f4r = p1r[0]
                f4i = p1r[1]
                f5r = p1r[posA]
                f5i = p1r[posAi]
                f6r = p1r[2]
                f6i = p1r[2 + 1]
                f7r = p1r[posB]
                f7i = p1r[posBi]

                t0r = f0r + f1r
                t0i = f0i + f1i
                f1r = f0r - f1r
                f1i = f0i - f1i
                t1r = f2r + f3r
                t1i = f2i + f3i
                f3r = f2r - f3r
                f3i = f2i - f3i
                f0r = f4r + f5r
                f0i = f4i + f5i
                f5r = f4r - f5r
                f5i = f4i - f5i
                f2r = f6r + f7r
                f2i = f6i + f7i
                f7r = f6r - f7r
                f7i = f6i - f7i

                p1r.pointee = t0r
                p1r.advanced(by: 1).pointee = t0i
                p1r.advanced(by: 2).pointee = f1r
                p1r.advanced(by: 3).pointee = f1i
                p1r.advanced(by: posA).pointee = t1r
                p1r.advanced(by: posAi).pointee = t1i
                p1r.advanced(by: posB).pointee = f3r
                p1r.advanced(by: posBi).pointee = f3i
                p0r.pointee = f0r
                p0r.advanced(by: 1).pointee = f0i
                p0r.advanced(by: 2).pointee = f5r
                p0r.advanced(by: 3).pointee = f5i
                p0r.advanced(by: posA).pointee = f2r
                p0r.advanced(by: posAi).pointee = f2i
                p0r.advanced(by: posB).pointee = f7r
                p0r.advanced(by: posBi).pointee = f7i

                p0r -= UnsafeMutablePointer<Float>.Stride(Nrems2)
                f0r = (p0r).pointee
                f0i = (p0r + 1).pointee
                f1r = (p0r + posA).pointee
                f1i = (p0r + posAi).pointee
                iCol -= 1
                p1r = IOP + Int(BRLow[Int(iCol)]) * 4
            }

            f2r = (p0r + 2).pointee
            f2i = (p0r + (2 + 1)).pointee
            f3r = (p0r + posB).pointee
            f3i = (p0r + posBi).pointee

            t0r = f0r + f1r
            t0i = f0i + f1i
            f1r = f0r - f1r
            f1i = f0i - f1i
            t1r = f2r + f3r
            t1i = f2i + f3i
            f3r = f2r - f3r
            f3i = f2i - f3i

            (p0r).pointee = t0r
            (p0r + 1).pointee = t0i
            (p0r + 2).pointee = f1r
            (p0r + (2 + 1)).pointee = f1i
            (p0r + posA).pointee = t1r
            (p0r + posAi).pointee = t1i
            (p0r + posB).pointee = f3r
            (p0r + posBi).pointee = f3i
        }
    }
}

func swift_bfstages(_ ioptr: UnsafeMutablePointer<Float>, _ M: Int32, _ Utbl: UnsafeMutablePointer<Float>, _ Ustride: Int32, _ NDiffU: Int32, _ StageCnt: Int32) {
    var NDiffU = NDiffU
    var pos: UInt
    var posi: UInt
    var pinc: UInt
    var pnext: UInt
    var NSameU: UInt
    var Uinc: Int
    var Uinc2: Int
    var Uinc4: Int
    var DiffUCnt: UInt
    var SameUCnt: UInt
    var U2toU3: UInt

    var pstrt: UnsafeMutablePointer<Float>
    var p0r, p1r, p2r, p3r: UnsafeMutablePointer<Float>
    var u0r, u0i, u1r, u1i, u2r, u2i: UnsafeMutablePointer<Float>

    var w0r, w0i, w1r, w1i, w2r, w2i, w3r, w3i: Float
    var f0r, f0i, f1r, f1i, f2r, f2i, f3r, f3i: Float
    var f4r, f4i, f5r, f5i, f6r, f6i, f7r, f7i: Float
    var t0r, t0i, t1r, t1i: Float
    let Two: Float = 2.0

    pinc = UInt(NDiffU * 2)
    pnext = pinc * 8
    pos = pinc * 4
    posi = pos + 1
    NSameU = UInt(pow(2.0, Double(M))) / 8 / UInt(NDiffU)
    Uinc = Int(NSameU) * Int(Ustride)
    Uinc2 = Uinc * 2
    Uinc4 = Uinc * 4
    U2toU3 = (UInt(pow(2.0, Double(M))) / 8) * UInt(Ustride)
    for _ in 0..<StageCnt {
        u0r = Utbl
        u0i = Utbl + Int(pow(2.0, Double(M - 2))) * Int(Ustride)
        u1r = u0r
        u1i = u0i
        u2r = u0r
        u2i = u0i

        w0r = u0r.pointee
        w0i = u0i.pointee
        w1r = u1r.pointee
        w1i = u1i.pointee
        w2r = u2r.pointee
        w2i = u2i.pointee
        w3r = (u2r + UnsafeMutablePointer<Float>.Stride(U2toU3)).pointee
        w3i = (u2i - UnsafeMutablePointer<Float>.Stride(U2toU3)).pointee

        pstrt = ioptr

        p0r = pstrt
        p1r = pstrt + UnsafeMutablePointer<Float>.Stride(pinc)
        p2r = p1r + UnsafeMutablePointer<Float>.Stride(pinc)
        p3r = p2r + UnsafeMutablePointer<Float>.Stride(pinc)

        /* Butterflys           */
        /*
           f0   -       -       t0      -       -       f0      -       -       f0
           f1   - w0-   f1      -       -       f1      -       -       f1
           f2   -       -       f2      - w1-   f2      -       -       f4
           f3   - w0-   t1      - iw1-  f3      -       -       f5

           f4   -       -       t0      -       -       f4      - w2-   t0
           f5   - w0-   f5      -       -       f5      - w3-   t1
           f6   -       -       f6      - w1-   f6      - iw2-  f6
           f7   - w0-   t1      - iw1-  f7      - iw3-  f7
         */

        DiffUCnt = UInt(NDiffU)
        while DiffUCnt > 0 {
            f0r = p0r.pointee
            f0i = p0r.advanced(by: 1).pointee
            f1r = p1r.pointee
            f1i = p1r.advanced(by: 1).pointee
            SameUCnt = NSameU - 1
            while SameUCnt > 0 {
                f2r = p2r.pointee
                f2i = p2r.advanced(by: 1).pointee
                f3r = p3r.pointee
                f3i = p3r.advanced(by: 1).pointee

                t0r = f0r + f1r * w0r + f1i * w0i
                t0i = f0i - f1r * w0i + f1i * w0r
                f1r = f0r * Two - t0r
                f1i = f0i * Two - t0i

                f4r = p0r.advanced(by: Int(pos)).pointee
                f4i = p0r.advanced(by: Int(posi)).pointee
                f5r = p1r.advanced(by: Int(pos)).pointee
                f5i = p1r.advanced(by: Int(posi)).pointee

                f6r = p2r.advanced(by: Int(pos)).pointee
                f6i = p2r.advanced(by: Int(posi)).pointee
                f7r = p3r.advanced(by: Int(pos)).pointee
                f7i = p3r.advanced(by: Int(posi)).pointee

                t1r = f2r - f3r * w0r - f3i * w0i
                t1i = f2i + f3r * w0i - f3i * w0r
                f2r = f2r * Two - t1r
                f2i = f2i * Two - t1i

                f0r = t0r + f2r * w1r + f2i * w1i
                f0i = t0i - f2r * w1i + f2i * w1r
                f2r = t0r * Two - f0r
                f2i = t0i * Two - f0i

                f3r = f1r + t1r * w1i - t1i * w1r
                f3i = f1i + t1r * w1r + t1i * w1i
                f1r = f1r * Two - f3r
                f1i = f1i * Two - f3i

                t0r = f4r + f5r * w0r + f5i * w0i
                t0i = f4i - f5r * w0i + f5i * w0r
                f5r = f4r * Two - t0r
                f5i = f4i * Two - t0i

                t1r = f6r - f7r * w0r - f7i * w0i
                t1i = f6i + f7r * w0i - f7i * w0r
                f6r = f6r * Two - t1r
                f6i = f6i * Two - t1i

                f4r = t0r + f6r * w1r + f6i * w1i
                f4i = t0i - f6r * w1i + f6i * w1r
                f6r = t0r * Two - f4r
                f6i = t0i * Two - f4i

                f7r = f5r + t1r * w1i - t1i * w1r
                f7i = f5i + t1r * w1r + t1i * w1i
                f5r = f5r * Two - f7r
                f5i = f5i * Two - f7i

                t0r = f0r - f4r * w2r - f4i * w2i
                t0i = f0i + f4r * w2i - f4i * w2r
                f0r = f0r * Two - t0r
                f0i = f0i * Two - t0i

                t1r = f1r - f5r * w3r - f5i * w3i
                t1i = f1i + f5r * w3i - f5i * w3r
                f1r = f1r * Two - t1r
                f1i = f1i * Two - t1i

                p0r.advanced(by: Int(pos)).pointee = t0r
                p1r.advanced(by: Int(pos)).pointee = t1r
                p0r.advanced(by: Int(posi)).pointee = t0i
                p1r.advanced(by: Int(posi)).pointee = t1i
                p0r.pointee = f0r
                p1r.pointee = f1r
                p0r.advanced(by: 1).pointee = f0i
                p1r.advanced(by: 1).pointee = f1i

                p0r += UnsafeMutablePointer<Float>.Stride(pnext)
                f0r = p0r.pointee
                f0i = (p0r + 1).pointee

                p1r += UnsafeMutablePointer<Float>.Stride(pnext)

                f1r = p1r.pointee
                f1i = (p1r + 1).pointee

                f4r = f2r - f6r * w2i + f6i * w2r
                f4i = f2i - f6r * w2r - f6i * w2i
                f6r = f2r * Two - f4r
                f6i = f2i * Two - f4i

                f5r = f3r - f7r * w3i + f7i * w3r
                f5i = f3i - f7r * w3r - f7i * w3i
                f7r = f3r * Two - f5r
                f7i = f3i * Two - f5i

                p2r.pointee = f4r
                p3r.pointee = f5r
                (p2r + 1).pointee = f4i
                (p3r + 1).pointee = f5i
                p2r.advanced(by: Int(pos)).pointee = f6r
                p3r.advanced(by: Int(pos)).pointee = f7r
                p2r.advanced(by: Int(posi)).pointee = f6i
                p3r.advanced(by: Int(posi)).pointee = f7i

                p2r += UnsafeMutablePointer<Float>.Stride(pnext)
                p3r += UnsafeMutablePointer<Float>.Stride(pnext)

                SameUCnt -= 1
            }

            f2r = p2r.pointee
            f2i = (p2r + 1).pointee
            f3r = p3r.pointee
            f3i = (p3r + 1).pointee

            t0r = f0r + f1r * w0r + f1i * w0i
            t0i = f0i - f1r * w0i + f1i * w0r
            f1r = f0r * Two - t0r
            f1i = f0i * Two - t0i

            f4r = p0r.advanced(by: Int(pos)).pointee
            f4i = p0r.advanced(by: Int(posi)).pointee
            f5r = p1r.advanced(by: Int(pos)).pointee
            f5i = p1r.advanced(by: Int(posi)).pointee

            f6r = p2r.advanced(by: Int(pos)).pointee
            f6i = p2r.advanced(by: Int(posi)).pointee
            f7r = p3r.advanced(by: Int(pos)).pointee
            f7i = p3r.advanced(by: Int(posi)).pointee

            t1r = f2r - f3r * w0r - f3i * w0i
            t1i = f2i + f3r * w0i - f3i * w0r
            f2r = f2r * Two - t1r
            f2i = f2i * Two - t1i

            f0r = t0r + f2r * w1r + f2i * w1i
            f0i = t0i - f2r * w1i + f2i * w1r
            f2r = t0r * Two - f0r
            f2i = t0i * Two - f0i

            f3r = f1r + t1r * w1i - t1i * w1r
            f3i = f1i + t1r * w1r + t1i * w1i
            f1r = f1r * Two - f3r
            f1i = f1i * Two - f3i

            if DiffUCnt == NDiffU / 2 {
                Uinc4 = -Uinc4
            }

            u0r += Uinc4
            u0i -= Uinc4
            u1r += Uinc2
            u1i -= Uinc2
            u2r += Uinc
            u2i -= Uinc

            pstrt += 2

            t0r = f4r + f5r * w0r + f5i * w0i
            t0i = f4i - f5r * w0i + f5i * w0r
            f5r = f4r * Two - t0r
            f5i = f4i * Two - t0i

            t1r = f6r - f7r * w0r - f7i * w0i
            t1i = f6i + f7r * w0i - f7i * w0r
            f6r = f6r * Two - t1r
            f6i = f6i * Two - t1i

            f4r = t0r + f6r * w1r + f6i * w1i
            f4i = t0i - f6r * w1i + f6i * w1r
            f6r = t0r * Two - f4r
            f6i = t0i * Two - f4i

            f7r = f5r + t1r * w1i - t1i * w1r
            f7i = f5i + t1r * w1r + t1i * w1i
            f5r = f5r * Two - f7r
            f5i = f5i * Two - f7i

            w0r = u0r.pointee
            w0i = u0i.pointee
            w1r = u1r.pointee
            w1i = u1i.pointee

            if DiffUCnt <= NDiffU / 2 {
                w0r = -w0r
            }

            t0r = f0r - f4r * w2r - f4i * w2i
            t0i = f0i + f4r * w2i - f4i * w2r
            f0r = f0r * Two - t0r
            f0i = f0i * Two - t0i

            f4r = f2r - f6r * w2i + f6i * w2r
            f4i = f2i - f6r * w2r - f6i * w2i
            f6r = f2r * Two - f4r
            f6i = f2i * Two - f4i

            p0r.advanced(by: Int(pos)).pointee = t0r
            p2r.pointee = f4r
            p0r.advanced(by: Int(posi)).pointee = t0i
            p2r.advanced(by: 1).pointee = f4i
            w2r = u2r.pointee
            w2i = u2i.pointee
            p0r.pointee = f0r
            p2r.advanced(by: Int(pos)).pointee = f6r
            p0r.advanced(by: 1).pointee = f0i
            p2r.advanced(by: Int(posi)).pointee = f6i

            p0r = pstrt
            p2r = pstrt.advanced(by: Int(pinc + pinc))

            t1r = f1r - f5r * w3r - f5i * w3i
            t1i = f1i + f5r * w3i - f5i * w3r
            f1r = f1r * Two - t1r
            f1i = f1i * Two - t1i

            f5r = f3r - f7r * w3i + f7i * w3r
            f5i = f3i - f7r * w3r - f7i * w3i
            f7r = f3r * Two - f5r
            f7i = f3i * Two - f5i

            p1r.advanced(by: Int(pos)).pointee = t1r
            p3r.pointee = f5r
            p1r.advanced(by: Int(posi)).pointee = t1i
            p3r.advanced(by: 1).pointee = f5i
            w3r = (u2r + UnsafeMutablePointer<Float>.Stride(U2toU3)).pointee
            w3i = (u2i - UnsafeMutablePointer<Float>.Stride(U2toU3)).pointee
            p1r.pointee = f1r
            p3r.advanced(by: Int(pos)).pointee = f7r
            p1r.advanced(by: 1).pointee = f1i
            p3r.advanced(by: Int(posi)).pointee = f7i

            p1r = pstrt.advanced(by: Int(pinc))
            p3r = p2r.advanced(by: Int(pinc))

            DiffUCnt -= 1
        }

        NSameU /= 8
        Uinc /= 8
        Uinc2 /= 8
        Uinc4 = Uinc * 4
        NDiffU *= 8
        pinc *= 8
        pnext *= 8
        pos *= 8
        posi = pos + 1
    }
}

// MARK: - FFT Tables

private func swiftfftCosInit(M: Int, Utbl: UnsafeMutablePointer<Float>) {
    let fftN = pow2(M)
    Utbl[0] = 1.0
    for i in 1..<fftN / 4 {
        Utbl[i] = cos(2.0 * .pi * Float(i) / Float(fftN))
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
