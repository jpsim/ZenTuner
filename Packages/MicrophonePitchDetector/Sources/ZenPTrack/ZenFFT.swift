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

// TODO: Remove this file in favor of the Accelerate framework's FFT support

// Since this file was ported from C with many variable names preserved, disable SwiftLint
// swiftlint:disable:next blanket_disable_command
// swiftlint:disable all

private let SQRT_TWO = sqrtf(2)
private let MCACHE = 11 - (MemoryLayout<Float>.size / 8)

// MARK: - Public API

final class ZenFFT {
    private var utbl: [Float]
    private var brLow: [Int]
    private let logSize: Int

    init(M: Int, size: Double) {
        logSize = Int(log2(size))
        utbl = fftCosInit(M)
        brLow = fftBRInit(M)
    }

    func compute(buf: inout [Float]) {
        ffts1(&buf, logSize, &utbl, &brLow)
    }
}

// MARK: - Private Compute

private func ffts1(_ ioptr: inout [Float], _ M: Int, _ Utbl: inout [Float], _ BRLow: inout [Int]) {
    bitrevR2(&ioptr, M, &BRLow)

    let StageCnt = (M - 1) / 3
    var NDiffU = 2
    if (M - 1 - (StageCnt * 3)) == 1 {
        bfR2(&ioptr, M, NDiffU)
        NDiffU *= 2
    } else if (M - 1 - (StageCnt * 3)) == 2 {
        bfR4(&ioptr, M, NDiffU, SQRT_TWO)
        NDiffU *= 4
    }

    if M <= MCACHE {
        bfstages(&ioptr, M, &Utbl, 1, NDiffU, StageCnt)
    } else {
        fftrecurs(&ioptr, M, &Utbl, 1, NDiffU, StageCnt)
    }
}

private func fftrecurs(_ ioptr: UnsafeMutablePointer<Float>, _ M: Int, _ Utbl: inout [Float], _ Ustride: Int, _ NDiffU: Int, _ StageCnt: Int) {
    guard M > MCACHE else {
        bfstages(ioptr, M, &Utbl, Ustride, NDiffU, StageCnt)
        return
    }

    let multiplier = pow2(M - 3) * 2
    for i1 in 0..<8 {
        fftrecurs(ioptr + i1 * multiplier, M - 3, &Utbl, 8 * Ustride, NDiffU, StageCnt - 1)
    }

    bfstages(ioptr, M, &Utbl, Ustride, multiplier / 2, 1)
}

private func bfR2(_ ioptr: UnsafeMutablePointer<Float>, _ M: Int, _ NDiffU: Int) {
    let pos = 2
    let posi = pos + 1
    let pinc = NDiffU * 2
    let pnext = pinc * 4
    let NSameU = pow2(M) / 4 / NDiffU
    let pstrt = ioptr
    var p0r = pstrt
    var p1r = pstrt + pinc
    var p2r = p1r + pinc
    var p3r = p2r + pinc

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

        p0r += pnext
        p1r += pnext
        p2r += pnext
        p3r += pnext
    }
}

private func bfR4(_ ioptr: UnsafeMutablePointer<Float>, _ M: Int, _ NDiffU: Int, _ sqrttwo: Float) {
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

private func bitrevR2(_ ioptr: UnsafeMutablePointer<Float>, _ M: Int, _ BRLow: UnsafeMutablePointer<Int>) {
    var f0r, f0i, f1r, f1i, f2r, f2i, f3r, f3i, f4r, f4i, f5r, f5i, f6r, f6i, f7r, f7i, t0r, t0i, t1r, t1i: Float
    var p0r, p1r, IOP, iolimit: UnsafeMutablePointer<Float>
    var iCol: Int
    var posA, posAi, posB, posBi: Int

    let Nrems2 = pow2((M + 3) / 2)
    let Nroot_1_ColInc = pow2(M) - Nrems2
    let Nroot_1 = pow2(M / 2 - 1) - 1
    let ColstartShift = (M + 1) / 2 + 1

    posA = pow2(M) /* 1/2 of POW2(M) complexes */
    posAi = posA + 1
    posB = posA + 2
    posBi = posB + 1

    iolimit = ioptr + UnsafeMutablePointer<Float>.Stride(Nrems2)
    for ioptr in stride(from: ioptr, to: iolimit, by: pow2(M / 2 + 1)) {
        for Colstart in (0...Nroot_1).reversed() {
            iCol = Nroot_1
            p0r = ioptr + Nroot_1_ColInc + BRLow[Colstart] * 4
            IOP = ioptr + (Colstart << ColstartShift)
            p1r = IOP + BRLow[iCol] * 4
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

                p1r[0] = t0r
                p1r[1] = t0i
                p1r[2] = f1r
                p1r[3] = f1i
                p1r[posA] = t1r
                p1r[posAi] = t1i
                p1r[posB] = f3r
                p1r[posBi] = f3i
                p0r[0] = f0r
                p0r[1] = f0i
                p0r[2] = f5r
                p0r[3] = f5i
                p0r[posA] = f2r
                p0r[posAi] = f2i
                p0r[posB] = f7r
                p0r[posBi] = f7i

                p0r -= Nrems2
                f0r = p0r[0]
                f0i = p0r[1]
                f1r = p0r[posA]
                f1i = p0r[posAi]
                iCol -= 1
                p1r = IOP + BRLow[iCol] * 4
            }

            f2r = p0r[2]
            f2i = p0r[3]
            f3r = p0r[posB]
            f3i = p0r[posBi]

            t0r = f0r + f1r
            t0i = f0i + f1i
            f1r = f0r - f1r
            f1i = f0i - f1i
            t1r = f2r + f3r
            t1i = f2i + f3i
            f3r = f2r - f3r
            f3i = f2i - f3i

            p0r[0] = t0r
            p0r[1] = t0i
            p0r[2] = f1r
            p0r[3] = f1i
            p0r[posA] = t1r
            p0r[posAi] = t1i
            p0r[posB] = f3r
            p0r[posBi] = f3i
        }
    }
}

private func bfstages(_ ioptr: UnsafeMutablePointer<Float>, _ M: Int, _ Utbl: UnsafeMutablePointer<Float>, _ Ustride: Int, _ NDiffU: Int, _ StageCnt: Int) {
    var NDiffU = NDiffU
    var pos: Int
    var posi: Int
    var pinc: Int
    var pnext: Int
    var NSameU: Int
    var Uinc: Int
    var Uinc2: Int
    var Uinc4: Int
    var DiffUCnt: Int
    var SameUCnt: Int
    var U2toU3: Int

    var pstrt: UnsafeMutablePointer<Float>
    var p0r, p1r, p2r, p3r: UnsafeMutablePointer<Float>
    var u0r, u0i, u1r, u1i, u2r, u2i: UnsafeMutablePointer<Float>

    var w0r, w0i, w1r, w1i, w2r, w2i, w3r, w3i: Float
    var f0r, f0i, f1r, f1i, f2r, f2i, f3r, f3i: Float
    var f4r, f4i, f5r, f5i, f6r, f6i, f7r, f7i: Float
    var t0r, t0i, t1r, t1i: Float
    let Two: Float = 2.0

    pinc = NDiffU * 2
    pnext = pinc * 8
    pos = pinc * 4
    posi = pos + 1
    NSameU = pow2(M) / 8 / NDiffU
    Uinc = NSameU * Ustride
    Uinc2 = Uinc * 2
    Uinc4 = Uinc * 4
    U2toU3 = (pow2(M) / 8) * Ustride
    for _ in 0..<StageCnt {
        u0r = Utbl
        u0i = Utbl + pow2(M - 2) * Ustride
        u1r = u0r
        u1i = u0i
        u2r = u0r
        u2i = u0i

        w0r = u0r[0]
        w0i = u0i[0]
        w1r = u1r[0]
        w1i = u1i[0]
        w2r = u2r[0]
        w2i = u2i[0]
        w3r = u2r[U2toU3]
        w3i = u2i[-U2toU3]

        pstrt = ioptr

        p0r = pstrt
        p1r = pstrt + pinc
        p2r = p1r + pinc
        p3r = p2r + pinc

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

        DiffUCnt = NDiffU
        while DiffUCnt > 0 {
            f0r = p0r[0]
            f0i = p0r[1]
            f1r = p1r[0]
            f1i = p1r[1]
            SameUCnt = NSameU - 1
            while SameUCnt > 0 {
                f2r = p2r[0]
                f2i = p2r[1]
                f3r = p3r[0]
                f3i = p3r[1]

                t0r = f0r + f1r * w0r + f1i * w0i
                t0i = f0i - f1r * w0i + f1i * w0r
                f1r = f0r * Two - t0r
                f1i = f0i * Two - t0i

                f4r = p0r[pos]
                f4i = p0r[posi]
                f5r = p1r[pos]
                f5i = p1r[posi]

                f6r = p2r[pos]
                f6i = p2r[posi]
                f7r = p3r[pos]
                f7i = p3r[posi]

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

                p0r[pos] = t0r
                p1r[pos] = t1r
                p0r[posi] = t0i
                p1r[posi] = t1i
                p0r[0] = f0r
                p1r[0] = f1r
                p0r[1] = f0i
                p1r[1] = f1i

                p0r += pnext
                f0r = p0r[0]
                f0i = p0r[1]

                p1r += pnext

                f1r = p1r[0]
                f1i = p1r[1]

                f4r = f2r - f6r * w2i + f6i * w2r
                f4i = f2i - f6r * w2r - f6i * w2i
                f6r = f2r * Two - f4r
                f6i = f2i * Two - f4i

                f5r = f3r - f7r * w3i + f7i * w3r
                f5i = f3i - f7r * w3r - f7i * w3i
                f7r = f3r * Two - f5r
                f7i = f3i * Two - f5i

                p2r[0] = f4r
                p3r[0] = f5r
                p2r[1] = f4i
                p3r[1] = f5i
                p2r[pos] = f6r
                p3r[pos] = f7r
                p2r[posi] = f6i
                p3r[posi] = f7i

                p2r += pnext
                p3r += pnext

                SameUCnt -= 1
            }

            f2r = p2r[0]
            f2i = p2r[1]
            f3r = p3r[0]
            f3i = p3r[1]

            t0r = f0r + f1r * w0r + f1i * w0i
            t0i = f0i - f1r * w0i + f1i * w0r
            f1r = f0r * Two - t0r
            f1i = f0i * Two - t0i

            f4r = p0r[pos]
            f4i = p0r[posi]
            f5r = p1r[pos]
            f5i = p1r[posi]

            f6r = p2r[pos]
            f6i = p2r[posi]
            f7r = p3r[pos]
            f7i = p3r[posi]

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

            w0r = u0r[0]
            w0i = u0i[0]
            w1r = u1r[0]
            w1i = u1i[0]

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

            p0r[pos] = t0r
            p2r[0] = f4r
            p0r[posi] = t0i
            p2r[1] = f4i
            w2r = u2r[0]
            w2i = u2i[0]
            p0r[0] = f0r
            p2r[pos] = f6r
            p0r[1] = f0i
            p2r[posi] = f6i

            p0r = pstrt
            p2r = pstrt.advanced(by: pinc + pinc)

            t1r = f1r - f5r * w3r - f5i * w3i
            t1i = f1i + f5r * w3i - f5i * w3r
            f1r = f1r * Two - t1r
            f1i = f1i * Two - t1i

            f5r = f3r - f7r * w3i + f7i * w3r
            f5i = f3i - f7r * w3r - f7i * w3i
            f7r = f3r * Two - f5r
            f7i = f3i * Two - f5i

            p1r[pos] = t1r
            p3r[0] = f5r
            p1r[posi] = t1i
            p3r[1] = f5i
            w3r = u2r[U2toU3]
            w3i = u2i[-U2toU3]
            p1r[0] = f1r
            p3r[pos] = f7r
            p1r[1] = f1i
            p3r[posi] = f7i

            p1r = pstrt.advanced(by: pinc)
            p3r = p2r.advanced(by: pinc)

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

private func fftCosInit(_ M: Int) -> [Float] {
    let fftN = pow2(M)
    return (0...fftN / 4).map { i in
        switch i {
        case 0:
            1
        case fftN / 4:
            0
        default:
            cos(2.0 * .pi * Float(i) / Float(fftN))
        }
    }
}

private func fftBRInit(_ M: Int) -> [Int] {
    let Mroot_1 = M / 2 - 1
    let Nroot_1 = pow2(Mroot_1)
    return (0..<Nroot_1).map { i in
        (1...Mroot_1).reduce(0) { sum, bit in
            sum + ((i & (1 << (bit - 1))) != 0 ? Nroot_1 >> bit : 0)
        }
    }
}

private func pow2(_ n: Int) -> Int {
    1 << n
}
