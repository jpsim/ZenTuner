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

#include <math.h>
#include <stdlib.h>
#include <string.h>
#include "CMicrophonePitchDetector.h"

#define MINBIN 3

#define THRSH 10.

#define FLTLEN 5

void ptrack_set_spec_pt2(zt_ptrack *p)
{
    float *spec = (float *)p->spec1.ptr;
    float *spectmp = (float *)p->spec2.ptr;
    int hop = p->hopsize;
    int n = 2 * hop;

    int k = 2 * FLTLEN;
    for (int i = 0; i < hop; i += 2) {
        spectmp[k]     = spec[i];
        spectmp[k + 1] = spec[i + 1];
        k += 4;
    }

    k = 2*FLTLEN+2;
    for (int i = n - 2; i >= 0; i -= 2) {
        spectmp[k]     = spec[i];
        spectmp[k + 1] = -spec[i + 1];
        k += 4;
    }

    k = 2*FLTLEN-2;
    for (int i = 2*FLTLEN; i < FLTLEN*4; i += 2) {
        spectmp[k]     = spectmp[i];
        spectmp[k + 1] = -spectmp[i + 1];
        k -= 2;
    }

    k = 2*FLTLEN+n;
    for (int i = 2*FLTLEN+n-2; i >= 0; i -= 2) {
        spectmp[k]     = spectmp[i];
        spectmp[k + 1] = -spectmp[k + 1];
        k += 2;
    }
}

void ptrack_pt2(int *npeak, int numpks, PEAK *peaklist, float totalpower, float *spec, int n)
{
    for (int i = 4*MINBIN; i < (4*(n-2)) && *npeak < numpks; i += 4) {
        float height = spec[i+2];
        float h1 = spec[i-2];
        float h2 = spec[i+6];
        float totalfreq, peakfr, tmpfr1, tmpfr2, m, v, stdev;

        if (height < h1 || height < h2 ||
            h1 < 0.00001*totalpower ||
            h2 < 0.00001*totalpower)
        {
            continue;
        }

        peakfr = ((spec[i-8] - spec[i+8]) * (2.0 * spec[i] - spec[i+8] - spec[i-8]) +
                  (spec[i-7] - spec[i+9]) * (2.0 * spec[i+1] - spec[i+9] - spec[i-7])) / (height + height);
        tmpfr1 =  ((spec[i-12] - spec[i+4]) * (2.0 * spec[i-4] - spec[i+4] - spec[i-12]) +
                   (spec[i-11] - spec[i+5]) * (2.0 * spec[i-3] - spec[i+5] - spec[i-11])) / (2.0 * h1) - 1;
        tmpfr2 = ((spec[i-4] - spec[i+12]) * (2.0 * spec[i+4] - spec[i+12] - spec[i-4]) +
                  (spec[i-3] - spec[i+13]) * (2.0 * spec[i+5] - spec[i+13] - spec[i-3])) / (2.0 * h2) + 1;

        m = 0.333333333333 * (peakfr + tmpfr1 + tmpfr2);
        v = 0.5 * ((peakfr-m)*(peakfr-m) +
                   (tmpfr1-m)*(tmpfr1-m) + (tmpfr2-m)*(tmpfr2-m));

        totalfreq = (i >> 2) + m;
        if (v * totalpower > THRSH * height ||
            v < 1.0e-30)
        {
            continue;
        }

        stdev = (float)sqrt((float)v);
        if (totalfreq < 4) {
            totalfreq = 4;
        }

        peaklist[*npeak].pwidth = stdev;
        peaklist[*npeak].ppow = height;
        peaklist[*npeak].ploudness = sqrt(sqrt(height));
        peaklist[*npeak].pfreq = totalfreq;
        (*npeak)++;
    }
}
