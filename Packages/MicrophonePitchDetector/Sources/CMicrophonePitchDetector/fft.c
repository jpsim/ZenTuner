/*
    FFT library
    based on public domain code by John Green <green_jt@vsdec.npt.nuwc.navy.mil>
    original version is available at
      http://hyperarchive.lcs.mit.edu/
            /HyperArchive/Archive/dev/src/ffts-for-risc-2-c.hqx
    ported to Csound by Istvan Varga, 2005
*/

#include <stdint.h>
#include <stdlib.h>
#include <math.h>
#include "CMicrophonePitchDetector.h"

#define POW2(m) ((uint32_t) 1 << (m))       /* integer power of 2 for m<32 */

/*****************
* parts of ffts1 *
*****************/

void bitrevR2(float *ioptr, int M, int16_t *BRLow)
{
    /*** bit reverse and first radix 2 stage of forward or inverse fft ***/
    float f0r, f0i, f1r, f1i, f2r, f2i, f3r, f3i, f4r, f4i, f5r, f5i, f6r, f6i, f7r, f7i, t0r, t0i, t1r, t1i;
    float *p0r, *p1r, *IOP, *iolimit;
    int Colstart, iCol;
    unsigned int posA, posAi, posB, posBi;

    const unsigned int Nrems2 = POW2((M + 3) / 2);
    const unsigned int Nroot_1_ColInc = POW2(M) - Nrems2;
    const unsigned int Nroot_1 = POW2(M / 2 - 1) - 1;
    const unsigned int ColstartShift = (M + 1) / 2 + 1;

    posA = POW2(M);               /* 1/2 of POW2(M) complexes */
    posAi = posA + 1;
    posB = posA + 2;
    posBi = posB + 1;

    iolimit = ioptr + Nrems2;
    for (; ioptr < iolimit; ioptr += POW2(M / 2 + 1)) {
      for (Colstart = Nroot_1; Colstart >= 0; Colstart--) {
        iCol = Nroot_1;
        p0r = ioptr + Nroot_1_ColInc + BRLow[Colstart] * 4;
        IOP = ioptr + (Colstart << ColstartShift);
        p1r = IOP + BRLow[iCol] * 4;
        f0r = *(p0r);
        f0i = *(p0r + 1);
        f1r = *(p0r + posA);
        f1i = *(p0r + posAi);
        for (; iCol > Colstart;) {
          f2r = *(p0r + 2);
          f2i = *(p0r + (2 + 1));
          f3r = *(p0r + posB);
          f3i = *(p0r + posBi);
          f4r = *(p1r);
          f4i = *(p1r + 1);
          f5r = *(p1r + posA);
          f5i = *(p1r + posAi);
          f6r = *(p1r + 2);
          f6i = *(p1r + (2 + 1));
          f7r = *(p1r + posB);
          f7i = *(p1r + posBi);

          t0r = f0r + f1r;
          t0i = f0i + f1i;
          f1r = f0r - f1r;
          f1i = f0i - f1i;
          t1r = f2r + f3r;
          t1i = f2i + f3i;
          f3r = f2r - f3r;
          f3i = f2i - f3i;
          f0r = f4r + f5r;
          f0i = f4i + f5i;
          f5r = f4r - f5r;
          f5i = f4i - f5i;
          f2r = f6r + f7r;
          f2i = f6i + f7i;
          f7r = f6r - f7r;
          f7i = f6i - f7i;

          *(p1r) = t0r;
          *(p1r + 1) = t0i;
          *(p1r + 2) = f1r;
          *(p1r + (2 + 1)) = f1i;
          *(p1r + posA) = t1r;
          *(p1r + posAi) = t1i;
          *(p1r + posB) = f3r;
          *(p1r + posBi) = f3i;
          *(p0r) = f0r;
          *(p0r + 1) = f0i;
          *(p0r + 2) = f5r;
          *(p0r + (2 + 1)) = f5i;
          *(p0r + posA) = f2r;
          *(p0r + posAi) = f2i;
          *(p0r + posB) = f7r;
          *(p0r + posBi) = f7i;

          p0r -= Nrems2;
          f0r = *(p0r);
          f0i = *(p0r + 1);
          f1r = *(p0r + posA);
          f1i = *(p0r + posAi);
          iCol -= 1;
          p1r = IOP + BRLow[iCol] * 4;
        }
        f2r = *(p0r + 2);
        f2i = *(p0r + (2 + 1));
        f3r = *(p0r + posB);
        f3i = *(p0r + posBi);

        t0r = f0r + f1r;
        t0i = f0i + f1i;
        f1r = f0r - f1r;
        f1i = f0i - f1i;
        t1r = f2r + f3r;
        t1i = f2i + f3i;
        f3r = f2r - f3r;
        f3i = f2i - f3i;

        *(p0r) = t0r;
        *(p0r + 1) = t0i;
        *(p0r + 2) = f1r;
        *(p0r + (2 + 1)) = f1i;
        *(p0r + posA) = t1r;
        *(p0r + posAi) = t1i;
        *(p0r + posB) = f3r;
        *(p0r + posBi) = f3i;
      }
    }
}

void bfR2(float *ioptr, int M, int NDiffU)
{
    /*** 2nd radix 2 stage ***/
    unsigned int pos;
    unsigned int posi;
    unsigned int pinc;
    unsigned int pnext;
    unsigned int NSameU;
    unsigned int SameUCnt;

    float *pstrt;
    float *p0r, *p1r, *p2r, *p3r;

    float f0r, f0i, f1r, f1i, f2r, f2i, f3r, f3i;
    float f4r, f4i, f5r, f5i, f6r, f6i, f7r, f7i;

    pinc = NDiffU * 2;            /* 2 floats per complex */
    pnext = pinc * 4;
    pos = 2;
    posi = pos + 1;
    NSameU = POW2(M) / 4 / NDiffU;        /* 4 Us at a time */
    pstrt = ioptr;
    p0r = pstrt;
    p1r = pstrt + pinc;
    p2r = p1r + pinc;
    p3r = p2r + pinc;

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

    for (SameUCnt = NSameU; SameUCnt > 0; SameUCnt--) {

      f0r = *p0r;
      f1r = *p1r;
      f0i = *(p0r + 1);
      f1i = *(p1r + 1);
      f2r = *p2r;
      f3r = *p3r;
      f2i = *(p2r + 1);
      f3i = *(p3r + 1);

      f4r = f0r + f1r;
      f4i = f0i + f1i;
      f5r = f0r - f1r;
      f5i = f0i - f1i;

      f6r = f2r + f3r;
      f6i = f2i + f3i;
      f7r = f2r - f3r;
      f7i = f2i - f3i;

      *p0r = f4r;
      *(p0r + 1) = f4i;
      *p1r = f5r;
      *(p1r + 1) = f5i;
      *p2r = f6r;
      *(p2r + 1) = f6i;
      *p3r = f7r;
      *(p3r + 1) = f7i;

      f0r = *(p0r + pos);
      f1i = *(p1r + posi);
      f0i = *(p0r + posi);
      f1r = *(p1r + pos);
      f2r = *(p2r + pos);
      f3i = *(p3r + posi);
      f2i = *(p2r + posi);
      f3r = *(p3r + pos);

      f4r = f0r + f1i;
      f4i = f0i - f1r;
      f5r = f0r - f1i;
      f5i = f0i + f1r;

      f6r = f2r + f3i;
      f6i = f2i - f3r;
      f7r = f2r - f3i;
      f7i = f2i + f3r;

      *(p0r + pos) = f4r;
      *(p0r + posi) = f4i;
      *(p1r + pos) = f5r;
      *(p1r + posi) = f5i;
      *(p2r + pos) = f6r;
      *(p2r + posi) = f6i;
      *(p3r + pos) = f7r;
      *(p3r + posi) = f7i;

      p0r += pnext;
      p1r += pnext;
      p2r += pnext;
      p3r += pnext;
    }
}

void bfR4(float *ioptr, int M, int NDiffU, float sqrttwo)
{
    /*** 1 radix 4 stage ***/
    unsigned int pos;
    unsigned int posi;
    unsigned int pinc;
    unsigned int pnext;
    unsigned int pnexti;
    unsigned int NSameU;
    unsigned int SameUCnt;

    float *pstrt;
    float *p0r, *p1r, *p2r, *p3r;

    float w1r = 1.0 / sqrttwo;    /* cos(pi/4)   */
    float f0r, f0i, f1r, f1i, f2r, f2i, f3r, f3i;
    float f4r, f4i, f5r, f5i, f6r, f6i, f7r, f7i;
    float t1r, t1i;
    const float Two = 2.0;

    pinc = NDiffU * 2;            /* 2 floats per complex */
    pnext = pinc * 4;
    pnexti = pnext + 1;
    pos = 2;
    posi = pos + 1;
    NSameU = POW2(M) / 4 / NDiffU;        /* 4 pts per butterfly */
    pstrt = ioptr;
    p0r = pstrt;
    p1r = pstrt + pinc;
    p2r = p1r + pinc;
    p3r = p2r + pinc;

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

    f0r = *p0r;
    f1r = *p1r;
    f2r = *p2r;
    f3r = *p3r;
    f0i = *(p0r + 1);
    f1i = *(p1r + 1);
    f2i = *(p2r + 1);
    f3i = *(p3r + 1);

    f5r = f0r - f1r;
    f5i = f0i - f1i;
    f0r = f0r + f1r;
    f0i = f0i + f1i;

    f6r = f2r + f3r;
    f6i = f2i + f3i;
    f3r = f2r - f3r;
    f3i = f2i - f3i;

    for (SameUCnt = NSameU - 1; SameUCnt > 0; SameUCnt--) {

      f7r = f5r - f3i;
      f7i = f5i + f3r;
      f5r = f5r + f3i;
      f5i = f5i - f3r;

      f4r = f0r + f6r;
      f4i = f0i + f6i;
      f6r = f0r - f6r;
      f6i = f0i - f6i;

      f2r = *(p2r + pos);
      f2i = *(p2r + posi);
      f1r = *(p1r + pos);
      f1i = *(p1r + posi);
      f3i = *(p3r + posi);
      f0r = *(p0r + pos);
      f3r = *(p3r + pos);
      f0i = *(p0r + posi);

      *p3r = f7r;
      *p0r = f4r;
      *(p3r + 1) = f7i;
      *(p0r + 1) = f4i;
      *p1r = f5r;
      *p2r = f6r;
      *(p1r + 1) = f5i;
      *(p2r + 1) = f6i;

      f7r = f2r - f3i;
      f7i = f2i + f3r;
      f2r = f2r + f3i;
      f2i = f2i - f3r;

      f4r = f0r + f1i;
      f4i = f0i - f1r;
      t1r = f0r - f1i;
      t1i = f0i + f1r;

      f5r = t1r - f7r * w1r + f7i * w1r;
      f5i = t1i - f7r * w1r - f7i * w1r;
      f7r = t1r * Two - f5r;
      f7i = t1i * Two - f5i;

      f6r = f4r - f2r * w1r - f2i * w1r;
      f6i = f4i + f2r * w1r - f2i * w1r;
      f4r = f4r * Two - f6r;
      f4i = f4i * Two - f6i;

      f3r = *(p3r + pnext);
      f0r = *(p0r + pnext);
      f3i = *(p3r + pnexti);
      f0i = *(p0r + pnexti);
      f2r = *(p2r + pnext);
      f2i = *(p2r + pnexti);
      f1r = *(p1r + pnext);
      f1i = *(p1r + pnexti);

      *(p2r + pos) = f6r;
      *(p1r + pos) = f5r;
      *(p2r + posi) = f6i;
      *(p1r + posi) = f5i;
      *(p3r + pos) = f7r;
      *(p0r + pos) = f4r;
      *(p3r + posi) = f7i;
      *(p0r + posi) = f4i;

      f6r = f2r + f3r;
      f6i = f2i + f3i;
      f3r = f2r - f3r;
      f3i = f2i - f3i;

      f5r = f0r - f1r;
      f5i = f0i - f1i;
      f0r = f0r + f1r;
      f0i = f0i + f1i;

      p3r += pnext;
      p0r += pnext;
      p1r += pnext;
      p2r += pnext;
    }
    f7r = f5r - f3i;
    f7i = f5i + f3r;
    f5r = f5r + f3i;
    f5i = f5i - f3r;

    f4r = f0r + f6r;
    f4i = f0i + f6i;
    f6r = f0r - f6r;
    f6i = f0i - f6i;

    f2r = *(p2r + pos);
    f2i = *(p2r + posi);
    f1r = *(p1r + pos);
    f1i = *(p1r + posi);
    f3i = *(p3r + posi);
    f0r = *(p0r + pos);
    f3r = *(p3r + pos);
    f0i = *(p0r + posi);

    *p3r = f7r;
    *p0r = f4r;
    *(p3r + 1) = f7i;
    *(p0r + 1) = f4i;
    *p1r = f5r;
    *p2r = f6r;
    *(p1r + 1) = f5i;
    *(p2r + 1) = f6i;

    f7r = f2r - f3i;
    f7i = f2i + f3r;
    f2r = f2r + f3i;
    f2i = f2i - f3r;

    f4r = f0r + f1i;
    f4i = f0i - f1r;
    t1r = f0r - f1i;
    t1i = f0i + f1r;

    f5r = t1r - f7r * w1r + f7i * w1r;
    f5i = t1i - f7r * w1r - f7i * w1r;
    f7r = t1r * Two - f5r;
    f7i = t1i * Two - f5i;

    f6r = f4r - f2r * w1r - f2i * w1r;
    f6i = f4i + f2r * w1r - f2i * w1r;
    f4r = f4r * Two - f6r;
    f4i = f4i * Two - f6i;

    *(p2r + pos) = f6r;
    *(p1r + pos) = f5r;
    *(p2r + posi) = f6i;
    *(p1r + posi) = f5i;
    *(p3r + pos) = f7r;
    *(p0r + pos) = f4r;
    *(p3r + posi) = f7i;
    *(p0r + posi) = f4i;
}
