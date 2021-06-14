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

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

#define POW2(m) ((uint32_t) 1 << (m))       /* integer power of 2 for m<32 */

/* fft's with M bigger than this bust primary cache */
#define MCACHE  (11 - (sizeof(ZTFLOAT) / 8))

/* some math constants to 40 decimal places */
#define MYROOT2   1.414213562373095048801688724209698078569   /* sqrt(2)    */

/*****************************************************
* routines to initialize tables used by fft routines *
*****************************************************/

static void fftCosInit(int M, ZTFLOAT *Utbl)
{
    /* Compute Utbl, the cosine table for ffts  */
    /* of size (pow(2,M)/4 +1)                  */
    /* INPUTS                                   */
    /*   M = log2 of fft size                   */
    /* OUTPUTS                                  */
    /*   *Utbl = cosine table                   */
    unsigned int fftN = POW2(M);
    unsigned int i1;

    Utbl[0] = 1.0;
    for (i1 = 1; i1 < fftN/4; i1++)
      Utbl[i1] = cos((2.0 * M_PI * (ZTFLOAT)i1) / (ZTFLOAT)fftN);
    Utbl[fftN/4] = 0.0;
}

void fftBRInit(int M, int16_t *BRLow)
{
    /* Compute BRLow, the bit reversed table for ffts */
    /* of size pow(2,M/2 -1)                          */
    /* INPUTS                                         */
    /*   M = log2 of fft size                         */
    /* OUTPUTS                                        */
    /*   *BRLow = bit reversed counter table          */
    int Mroot_1 = M / 2 - 1;
    int Nroot_1 = POW2(Mroot_1);
    int i1;
    int bitsum;
    int bitmask;
    int bit;

    for (i1 = 0; i1 < Nroot_1; i1++) {
      bitsum = 0;
      bitmask = 1;
      for (bit = 1; bit <= Mroot_1; bitmask <<= 1, bit++)
        if (i1 & bitmask)
          bitsum = bitsum + (Nroot_1 >> bit);
      BRLow[i1] = bitsum;
    }
}

/*****************
* parts of ffts1 *
*****************/

static void bitrevR2(ZTFLOAT *ioptr, int M, int16_t *BRLow)
{
    /*** bit reverse and first radix 2 stage of forward or inverse fft ***/
    ZTFLOAT f0r;
    ZTFLOAT f0i;
    ZTFLOAT f1r;
    ZTFLOAT f1i;
    ZTFLOAT f2r;
    ZTFLOAT f2i;
    ZTFLOAT f3r;
    ZTFLOAT f3i;
    ZTFLOAT f4r;
    ZTFLOAT f4i;
    ZTFLOAT f5r;
    ZTFLOAT f5i;
    ZTFLOAT f6r;
    ZTFLOAT f6i;
    ZTFLOAT f7r;
    ZTFLOAT f7i;
    ZTFLOAT t0r;
    ZTFLOAT t0i;
    ZTFLOAT t1r;
    ZTFLOAT t1i;
    ZTFLOAT *p0r;
    ZTFLOAT *p1r;
    ZTFLOAT *IOP;
    ZTFLOAT *iolimit;
    int Colstart;
    int iCol;
    unsigned int posA;
    unsigned int posAi;
    unsigned int posB;
    unsigned int posBi;

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

static void fft2pt(ZTFLOAT *ioptr)
{
    /***   RADIX 2 fft      ***/
    ZTFLOAT f0r, f0i, f1r, f1i;
    ZTFLOAT t0r, t0i;

    /* bit reversed load */
    f0r = ioptr[0];
    f0i = ioptr[1];
    f1r = ioptr[2];
    f1i = ioptr[3];

    /* Butterflys           */
    /*
       f0   -       -       t0
       f1   -  1 -  f1
     */

    t0r = f0r + f1r;
    t0i = f0i + f1i;
    f1r = f0r - f1r;
    f1i = f0i - f1i;

    /* store result */
    ioptr[0] = t0r;
    ioptr[1] = t0i;
    ioptr[2] = f1r;
    ioptr[3] = f1i;
}

static void fft4pt(ZTFLOAT *ioptr)
{
    /***   RADIX 4 fft      ***/
    ZTFLOAT f0r, f0i, f1r, f1i, f2r, f2i, f3r, f3i;
    ZTFLOAT t0r, t0i, t1r, t1i;

    /* bit reversed load */
    f0r = ioptr[0];
    f0i = ioptr[1];
    f1r = ioptr[4];
    f1i = ioptr[5];
    f2r = ioptr[2];
    f2i = ioptr[3];
    f3r = ioptr[6];
    f3i = ioptr[7];

    /* Butterflys           */
    /*
       f0   -       -       t0      -       -       f0
       f1   -  1 -  f1      -       -       f1
       f2   -       -       f2      -  1 -  f2
       f3   -  1 -  t1      - -i -  f3
     */

    t0r = f0r + f1r;
    t0i = f0i + f1i;
    f1r = f0r - f1r;
    f1i = f0i - f1i;

    t1r = f2r - f3r;
    t1i = f2i - f3i;
    f2r = f2r + f3r;
    f2i = f2i + f3i;

    f0r = t0r + f2r;
    f0i = t0i + f2i;
    f2r = t0r - f2r;
    f2i = t0i - f2i;

    f3r = f1r - t1i;
    f3i = f1i + t1r;
    f1r = f1r + t1i;
    f1i = f1i - t1r;

    /* store result */
    ioptr[0] = f0r;
    ioptr[1] = f0i;
    ioptr[2] = f1r;
    ioptr[3] = f1i;
    ioptr[4] = f2r;
    ioptr[5] = f2i;
    ioptr[6] = f3r;
    ioptr[7] = f3i;
}

static void fft8pt(ZTFLOAT *ioptr)
{
    /***   RADIX 8 fft      ***/
    ZTFLOAT w0r = (ZTFLOAT)(1.0 / MYROOT2);    /* cos(pi/4)   */
    ZTFLOAT f0r, f0i, f1r, f1i, f2r, f2i, f3r, f3i;
    ZTFLOAT f4r, f4i, f5r, f5i, f6r, f6i, f7r, f7i;
    ZTFLOAT t0r, t0i, t1r, t1i;
    const ZTFLOAT Two = 2.0;

    /* bit reversed load */
    f0r = ioptr[0];
    f0i = ioptr[1];
    f1r = ioptr[8];
    f1i = ioptr[9];
    f2r = ioptr[4];
    f2i = ioptr[5];
    f3r = ioptr[12];
    f3i = ioptr[13];
    f4r = ioptr[2];
    f4i = ioptr[3];
    f5r = ioptr[10];
    f5i = ioptr[11];
    f6r = ioptr[6];
    f6i = ioptr[7];
    f7r = ioptr[14];
    f7i = ioptr[15];
    /* Butterflys           */
    /*
       f0   -       -       t0      -       -       f0      -       -       f0
       f1   -  1 -  f1      -       -       f1      -       -       f1
       f2   -       -       f2      -  1 -  f2      -       -       f2
       f3   -  1 -  t1      - -i -  f3      -       -       f3
       f4   -       -       t0      -       -       f4      -  1 -  t0
       f5   -  1 -  f5      -       -       f5      - w3 -  f4
       f6   -       -       f6      -  1 -  f6      - -i -  t1
       f7   -  1 -  t1      - -i -  f7      - iw3-  f6
     */

    t0r = f0r + f1r;
    t0i = f0i + f1i;
    f1r = f0r - f1r;
    f1i = f0i - f1i;

    t1r = f2r - f3r;
    t1i = f2i - f3i;
    f2r = f2r + f3r;
    f2i = f2i + f3i;

    f0r = t0r + f2r;
    f0i = t0i + f2i;
    f2r = t0r - f2r;
    f2i = t0i - f2i;

    f3r = f1r - t1i;
    f3i = f1i + t1r;
    f1r = f1r + t1i;
    f1i = f1i - t1r;

    t0r = f4r + f5r;
    t0i = f4i + f5i;
    f5r = f4r - f5r;
    f5i = f4i - f5i;

    t1r = f6r - f7r;
    t1i = f6i - f7i;
    f6r = f6r + f7r;
    f6i = f6i + f7i;

    f4r = t0r + f6r;
    f4i = t0i + f6i;
    f6r = t0r - f6r;
    f6i = t0i - f6i;

    f7r = f5r - t1i;
    f7i = f5i + t1r;
    f5r = f5r + t1i;
    f5i = f5i - t1r;

    t0r = f0r - f4r;
    t0i = f0i - f4i;
    f0r = f0r + f4r;
    f0i = f0i + f4i;

    t1r = f2r - f6i;
    t1i = f2i + f6r;
    f2r = f2r + f6i;
    f2i = f2i - f6r;

    f4r = f1r - f5r * w0r - f5i * w0r;
    f4i = f1i + f5r * w0r - f5i * w0r;
    f1r = f1r * Two - f4r;
    f1i = f1i * Two - f4i;

    f6r = f3r + f7r * w0r - f7i * w0r;
    f6i = f3i + f7r * w0r + f7i * w0r;
    f3r = f3r * Two - f6r;
    f3i = f3i * Two - f6i;

    /* store result */
    ioptr[0] = f0r;
    ioptr[1] = f0i;
    ioptr[2] = f1r;
    ioptr[3] = f1i;
    ioptr[4] = f2r;
    ioptr[5] = f2i;
    ioptr[6] = f3r;
    ioptr[7] = f3i;
    ioptr[8] = t0r;
    ioptr[9] = t0i;
    ioptr[10] = f4r;
    ioptr[11] = f4i;
    ioptr[12] = t1r;
    ioptr[13] = t1i;
    ioptr[14] = f6r;
    ioptr[15] = f6i;
}

static void bfR2(ZTFLOAT *ioptr, int M, int NDiffU)
{
    /*** 2nd radix 2 stage ***/
    unsigned int pos;
    unsigned int posi;
    unsigned int pinc;
    unsigned int pnext;
    unsigned int NSameU;
    unsigned int SameUCnt;

    ZTFLOAT *pstrt;
    ZTFLOAT *p0r, *p1r, *p2r, *p3r;

    ZTFLOAT f0r, f0i, f1r, f1i, f2r, f2i, f3r, f3i;
    ZTFLOAT f4r, f4i, f5r, f5i, f6r, f6i, f7r, f7i;

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

static void bfR4(ZTFLOAT *ioptr, int M, int NDiffU)
{
    /*** 1 radix 4 stage ***/
    unsigned int pos;
    unsigned int posi;
    unsigned int pinc;
    unsigned int pnext;
    unsigned int pnexti;
    unsigned int NSameU;
    unsigned int SameUCnt;

    ZTFLOAT *pstrt;
    ZTFLOAT *p0r, *p1r, *p2r, *p3r;

    ZTFLOAT w1r = 1.0 / MYROOT2;    /* cos(pi/4)   */
    ZTFLOAT f0r, f0i, f1r, f1i, f2r, f2i, f3r, f3i;
    ZTFLOAT f4r, f4i, f5r, f5i, f6r, f6i, f7r, f7i;
    ZTFLOAT t1r, t1i;
    const ZTFLOAT Two = 2.0;

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

static void bfstages(ZTFLOAT *ioptr, int M, ZTFLOAT *Utbl, int Ustride,
                     int NDiffU, int StageCnt)
{
    /***   RADIX 8 Stages   ***/
    unsigned int pos;
    unsigned int posi;
    unsigned int pinc;
    unsigned int pnext;
    unsigned int NSameU;
    int          Uinc;
    int          Uinc2;
    int          Uinc4;
    unsigned int DiffUCnt;
    unsigned int SameUCnt;
    unsigned int U2toU3;

    ZTFLOAT *pstrt;
    ZTFLOAT *p0r, *p1r, *p2r, *p3r;
    ZTFLOAT *u0r, *u0i, *u1r, *u1i, *u2r, *u2i;

    ZTFLOAT w0r, w0i, w1r, w1i, w2r, w2i, w3r, w3i;
    ZTFLOAT f0r, f0i, f1r, f1i, f2r, f2i, f3r, f3i;
    ZTFLOAT f4r, f4i, f5r, f5i, f6r, f6i, f7r, f7i;
    ZTFLOAT t0r, t0i, t1r, t1i;
    const ZTFLOAT Two = 2.0;

    pinc = NDiffU * 2;            /* 2 floats per complex */
    pnext = pinc * 8;
    pos = pinc * 4;
    posi = pos + 1;
    NSameU = POW2(M) / 8 / NDiffU;        /* 8 pts per butterfly */
    Uinc = (int) NSameU * Ustride;
    Uinc2 = Uinc * 2;
    Uinc4 = Uinc * 4;
    U2toU3 = (POW2(M) / 8) * Ustride;
    for (; StageCnt > 0; StageCnt--) {

      u0r = &Utbl[0];
      u0i = &Utbl[POW2(M - 2) * Ustride];
      u1r = u0r;
      u1i = u0i;
      u2r = u0r;
      u2i = u0i;

      w0r = *u0r;
      w0i = *u0i;
      w1r = *u1r;
      w1i = *u1i;
      w2r = *u2r;
      w2i = *u2i;
      w3r = *(u2r + U2toU3);
      w3i = *(u2i - U2toU3);

      pstrt = ioptr;

      p0r = pstrt;
      p1r = pstrt + pinc;
      p2r = p1r + pinc;
      p3r = p2r + pinc;

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

      for (DiffUCnt = NDiffU; DiffUCnt > 0; DiffUCnt--) {
        f0r = *p0r;
        f0i = *(p0r + 1);
        f1r = *p1r;
        f1i = *(p1r + 1);
        for (SameUCnt = NSameU - 1; SameUCnt > 0; SameUCnt--) {
          f2r = *p2r;
          f2i = *(p2r + 1);
          f3r = *p3r;
          f3i = *(p3r + 1);

          t0r = f0r + f1r * w0r + f1i * w0i;
          t0i = f0i - f1r * w0i + f1i * w0r;
          f1r = f0r * Two - t0r;
          f1i = f0i * Two - t0i;

          f4r = *(p0r + pos);
          f4i = *(p0r + posi);
          f5r = *(p1r + pos);
          f5i = *(p1r + posi);

          f6r = *(p2r + pos);
          f6i = *(p2r + posi);
          f7r = *(p3r + pos);
          f7i = *(p3r + posi);

          t1r = f2r - f3r * w0r - f3i * w0i;
          t1i = f2i + f3r * w0i - f3i * w0r;
          f2r = f2r * Two - t1r;
          f2i = f2i * Two - t1i;

          f0r = t0r + f2r * w1r + f2i * w1i;
          f0i = t0i - f2r * w1i + f2i * w1r;
          f2r = t0r * Two - f0r;
          f2i = t0i * Two - f0i;

          f3r = f1r + t1r * w1i - t1i * w1r;
          f3i = f1i + t1r * w1r + t1i * w1i;
          f1r = f1r * Two - f3r;
          f1i = f1i * Two - f3i;

          t0r = f4r + f5r * w0r + f5i * w0i;
          t0i = f4i - f5r * w0i + f5i * w0r;
          f5r = f4r * Two - t0r;
          f5i = f4i * Two - t0i;

          t1r = f6r - f7r * w0r - f7i * w0i;
          t1i = f6i + f7r * w0i - f7i * w0r;
          f6r = f6r * Two - t1r;
          f6i = f6i * Two - t1i;

          f4r = t0r + f6r * w1r + f6i * w1i;
          f4i = t0i - f6r * w1i + f6i * w1r;
          f6r = t0r * Two - f4r;
          f6i = t0i * Two - f4i;

          f7r = f5r + t1r * w1i - t1i * w1r;
          f7i = f5i + t1r * w1r + t1i * w1i;
          f5r = f5r * Two - f7r;
          f5i = f5i * Two - f7i;

          t0r = f0r - f4r * w2r - f4i * w2i;
          t0i = f0i + f4r * w2i - f4i * w2r;
          f0r = f0r * Two - t0r;
          f0i = f0i * Two - t0i;

          t1r = f1r - f5r * w3r - f5i * w3i;
          t1i = f1i + f5r * w3i - f5i * w3r;
          f1r = f1r * Two - t1r;
          f1i = f1i * Two - t1i;

          *(p0r + pos) = t0r;
          *(p1r + pos) = t1r;
          *(p0r + posi) = t0i;
          *(p1r + posi) = t1i;
          *p0r = f0r;
          *p1r = f1r;
          *(p0r + 1) = f0i;
          *(p1r + 1) = f1i;

          p0r += pnext;
          f0r = *p0r;
          f0i = *(p0r + 1);

          p1r += pnext;

          f1r = *p1r;
          f1i = *(p1r + 1);

          f4r = f2r - f6r * w2i + f6i * w2r;
          f4i = f2i - f6r * w2r - f6i * w2i;
          f6r = f2r * Two - f4r;
          f6i = f2i * Two - f4i;

          f5r = f3r - f7r * w3i + f7i * w3r;
          f5i = f3i - f7r * w3r - f7i * w3i;
          f7r = f3r * Two - f5r;
          f7i = f3i * Two - f5i;

          *p2r = f4r;
          *p3r = f5r;
          *(p2r + 1) = f4i;
          *(p3r + 1) = f5i;
          *(p2r + pos) = f6r;
          *(p3r + pos) = f7r;
          *(p2r + posi) = f6i;
          *(p3r + posi) = f7i;

          p2r += pnext;
          p3r += pnext;
        }

        f2r = *p2r;
        f2i = *(p2r + 1);
        f3r = *p3r;
        f3i = *(p3r + 1);

        t0r = f0r + f1r * w0r + f1i * w0i;
        t0i = f0i - f1r * w0i + f1i * w0r;
        f1r = f0r * Two - t0r;
        f1i = f0i * Two - t0i;

        f4r = *(p0r + pos);
        f4i = *(p0r + posi);
        f5r = *(p1r + pos);
        f5i = *(p1r + posi);

        f6r = *(p2r + pos);
        f6i = *(p2r + posi);
        f7r = *(p3r + pos);
        f7i = *(p3r + posi);

        t1r = f2r - f3r * w0r - f3i * w0i;
        t1i = f2i + f3r * w0i - f3i * w0r;
        f2r = f2r * Two - t1r;
        f2i = f2i * Two - t1i;

        f0r = t0r + f2r * w1r + f2i * w1i;
        f0i = t0i - f2r * w1i + f2i * w1r;
        f2r = t0r * Two - f0r;
        f2i = t0i * Two - f0i;

        f3r = f1r + t1r * w1i - t1i * w1r;
        f3i = f1i + t1r * w1r + t1i * w1i;
        f1r = f1r * Two - f3r;
        f1i = f1i * Two - f3i;

        if ((int) DiffUCnt == NDiffU / 2)
          Uinc4 = -Uinc4;

        u0r += Uinc4;
        u0i -= Uinc4;
        u1r += Uinc2;
        u1i -= Uinc2;
        u2r += Uinc;
        u2i -= Uinc;

        pstrt += 2;

        t0r = f4r + f5r * w0r + f5i * w0i;
        t0i = f4i - f5r * w0i + f5i * w0r;
        f5r = f4r * Two - t0r;
        f5i = f4i * Two - t0i;

        t1r = f6r - f7r * w0r - f7i * w0i;
        t1i = f6i + f7r * w0i - f7i * w0r;
        f6r = f6r * Two - t1r;
        f6i = f6i * Two - t1i;

        f4r = t0r + f6r * w1r + f6i * w1i;
        f4i = t0i - f6r * w1i + f6i * w1r;
        f6r = t0r * Two - f4r;
        f6i = t0i * Two - f4i;

        f7r = f5r + t1r * w1i - t1i * w1r;
        f7i = f5i + t1r * w1r + t1i * w1i;
        f5r = f5r * Two - f7r;
        f5i = f5i * Two - f7i;

        w0r = *u0r;
        w0i = *u0i;
        w1r = *u1r;
        w1i = *u1i;

        if ((int) DiffUCnt <= NDiffU / 2)
          w0r = -w0r;

        t0r = f0r - f4r * w2r - f4i * w2i;
        t0i = f0i + f4r * w2i - f4i * w2r;
        f0r = f0r * Two - t0r;
        f0i = f0i * Two - t0i;

        f4r = f2r - f6r * w2i + f6i * w2r;
        f4i = f2i - f6r * w2r - f6i * w2i;
        f6r = f2r * Two - f4r;
        f6i = f2i * Two - f4i;

        *(p0r + pos) = t0r;
        *p2r = f4r;
        *(p0r + posi) = t0i;
        *(p2r + 1) = f4i;
        w2r = *u2r;
        w2i = *u2i;
        *p0r = f0r;
        *(p2r + pos) = f6r;
        *(p0r + 1) = f0i;
        *(p2r + posi) = f6i;

        p0r = pstrt;
        p2r = pstrt + pinc + pinc;

        t1r = f1r - f5r * w3r - f5i * w3i;
        t1i = f1i + f5r * w3i - f5i * w3r;
        f1r = f1r * Two - t1r;
        f1i = f1i * Two - t1i;

        f5r = f3r - f7r * w3i + f7i * w3r;
        f5i = f3i - f7r * w3r - f7i * w3i;
        f7r = f3r * Two - f5r;
        f7i = f3i * Two - f5i;

        *(p1r + pos) = t1r;
        *p3r = f5r;
        *(p1r + posi) = t1i;
        *(p3r + 1) = f5i;
        w3r = *(u2r + U2toU3);
        w3i = *(u2i - U2toU3);
        *p1r = f1r;
        *(p3r + pos) = f7r;
        *(p1r + 1) = f1i;
        *(p3r + posi) = f7i;

        p1r = pstrt + pinc;
        p3r = p2r + pinc;
      }
      NSameU /= 8;
      Uinc /= 8;
      Uinc2 /= 8;
      Uinc4 = Uinc * 4;
      NDiffU *= 8;
      pinc *= 8;
      pnext *= 8;
      pos *= 8;
      posi = pos + 1;
    }
}

static void fftrecurs(ZTFLOAT *ioptr, int M, ZTFLOAT *Utbl, int Ustride, int NDiffU,
                      int StageCnt)
{
    /* recursive bfstages calls to maximize on chip cache efficiency */
    int i1;

    if (M <= (int) MCACHE)              /* fits on chip ? */
      bfstages(ioptr, M, Utbl, Ustride, NDiffU, StageCnt); /* RADIX 8 Stages */
    else {
      for (i1 = 0; i1 < 8; i1++) {
        fftrecurs(&ioptr[i1 * POW2(M - 3) * 2], M - 3, Utbl, 8 * Ustride,
                  NDiffU, StageCnt - 1);  /*  RADIX 8 Stages      */
      }
      bfstages(ioptr, M, Utbl, Ustride, POW2(M - 3), 1);  /*  RADIX 8 Stage */
    }
}

static void ffts1(ZTFLOAT *ioptr, int M, ZTFLOAT *Utbl, int16_t *BRLow)
{
    /* Compute in-place complex fft on the rows of the input array  */
    /* INPUTS                                                       */
    /*   *ioptr = input data array                                  */
    /*   M = log2 of fft size (ex M=10 for 1024 point fft)          */
    /*   *Utbl = cosine table                                       */
    /*   *BRLow = bit reversed counter table                        */
    /* OUTPUTS                                                      */
    /*   *ioptr = output data array                                 */

    int StageCnt;
    int NDiffU;

    switch (M) {
    case 0:
      break;
    case 1:
      fft2pt(ioptr);            /* a 2 pt fft */
      break;
    case 2:
      fft4pt(ioptr);            /* a 4 pt fft */
      break;
    case 3:
      fft8pt(ioptr);            /* an 8 pt fft */
      break;
    default:
      bitrevR2(ioptr, M, BRLow);  /* bit reverse and first radix 2 stage */
      StageCnt = (M - 1) / 3;     /* number of radix 8 stages           */
      NDiffU = 2;                 /* one radix 2 stage already complete */
      if ((M - 1 - (StageCnt * 3)) == 1) {
        bfR2(ioptr, M, NDiffU); /* 1 radix 2 stage */
        NDiffU *= 2;
      }
      if ((M - 1 - (StageCnt * 3)) == 2) {
        bfR4(ioptr, M, NDiffU); /* 1 radix 4 stage */
        NDiffU *= 4;
      }
      if (M <= (int) MCACHE)
        bfstages(ioptr, M, Utbl, 1, NDiffU, StageCnt);  /* RADIX 8 Stages */
      else
        fftrecurs(ioptr, M, Utbl, 1, NDiffU, StageCnt); /* RADIX 8 Stages */
    }
}

void zt_fft_init(zt_fft *fft, int M)
{
    ZTFLOAT *utbl;
    int16_t *BRLow;
    int16_t *BRLowCpx;
//    int i;

    /* init cos table */
    utbl = (ZTFLOAT*) malloc((POW2(M) / 4 + 1) * sizeof(ZTFLOAT));
    fftCosInit(M, utbl);

    BRLowCpx =
      (int16_t*) malloc(POW2(M / 2 - 1) * sizeof(int16_t));
    fftBRInit(M, BRLowCpx);

    /* init bit reversed table for real FFT */
     BRLow =
      (int16_t*) malloc(POW2((M - 1) / 2 - 1) * sizeof(int16_t));
    fftBRInit(M - 1, BRLow);

    fft->BRLow = BRLow;
    fft->BRLowCpx = BRLowCpx;
    fft->utbl = utbl;
}

void zt_fft_cpx(zt_fft *fft, ZTFLOAT *buf, int FFTsize)
{
//    ZTFLOAT *Utbl;
//    int16_t *BRLow;
    int   M = log2(FFTsize);
    ffts1(buf, M, fft->utbl, fft->BRLowCpx);
}

void zt_fft_destroy(zt_fft *fft)
{
    free(fft->utbl);
    free(fft->BRLow);
    free(fft->BRLowCpx);
}
