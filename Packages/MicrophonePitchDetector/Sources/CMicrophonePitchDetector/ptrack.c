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

#define MINFREQINBINS 5
#define NPREV 20
#define MINBW 0.03
#define BINPEROCT 48
#define BPEROOVERLOG2 69.24936196
#define FACTORTOBINS 4/0.0145453
#define BINGUARD 10
#define PARTIALDEVIANCE 0.023
#define DBSCAL 3.333
#define DBOFFSET -92.3
#define MINBIN 3

#define THRSH 10.

#define COEF1 ((float)(.5 * 1.227054))
#define COEF2 ((float)(.5 * -0.302385))
#define COEF3 ((float)(.5 * 0.095326))
#define COEF4 ((float)(.5 * -0.022748))
#define COEF5 ((float)(.5 * 0.002533))
#define FLTLEN 5

#define NPARTIALONSET ((int)(sizeof(partialonset)/sizeof(float)))

static const float partialonset[] =
{
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
};

typedef struct histopeak
{
  float hpitch;
  float hvalue;
  float hloud;
  int hindex;
  int hused;
} HISTOPEAK;

void ptrack(zt_data *sp, zt_ptrack *p)
{
    float *spec = (float *)p->spec1.ptr;
    float *spectmp = (float *)p->spec2.ptr;
    float *sig = (float *)p->signal.ptr;
    float *sinus  = (float *)p->sin.ptr;
    float *prev  = (float *)p->prev.ptr;
    PEAK  *peaklist = (PEAK *)p->peakarray.ptr;
    HISTOPEAK histpeak;
    int i, j, k, hop = p->hopsize, n = 2*hop, npeak = 0, logn = -1, count, tmp;
    float totalpower = 0, totalloudness = 0, totaldb = 0;
    float maxbin,  *histogram = spectmp + BINGUARD;
    float hzperbin = (float) p->sr / (n + n);
    int numpks = p->numpks;
    int indx, halfhop = hop>>1;
    float best;
    float cumpow = 0, cumstrength = 0, freqnum = 0, freqden = 0;
    int npartials = 0,  nbelow8 = 0;
    float putfreq;

    count = p->histcnt + 1;
    if (count == NPREV) count = 0;
    p->histcnt = count;

    tmp = n;
    while (tmp) {
        tmp >>= 1;
        logn++;
    }
    maxbin = BINPEROCT * (logn-2);
    for (i = 0, k = 0; i < hop; i++, k += 2) {
        spec[k]   = sig[i] * sinus[k];
        spec[k+1] = sig[i] * sinus[k+1];
    }

    zt_fft_cpx(&p->fft, spec, hop);

    for (i = 0, k = 2*FLTLEN; i < hop; i+=2, k += 4) {
        spectmp[k]   = spec[i];
        spectmp[k+1] = spec[i+1];
    }

    for (i = n - 2, k = 2*FLTLEN+2; i >= 0; i-=2, k += 4) {
        spectmp[k]   = spec[i];
        spectmp[k+1] = -spec[i+1];
    }

    for (i = (2*FLTLEN), k = (2*FLTLEN-2);i<FLTLEN*4; i+=2, k-=2) {
        spectmp[k]   = spectmp[i];
        spectmp[k+1] = -spectmp[i+1];
    }

    for (i = (2*FLTLEN+n-2), k =(2*FLTLEN+n); i>=0; i-=2, k+=2) {
        spectmp[k]   = spectmp[i];
        spectmp[k+1] = -spectmp[k+1];
    }

    for (i = j = 0, k = 2*FLTLEN; i < halfhop; i++, j+=8, k+=2) {
        float re,  im;

        re= COEF1 * ( prev[k-2] - prev[k+1]  + spectmp[k-2] - prev[k+1]) +
            COEF2 * ( prev[k-3] - prev[k+2]  + spectmp[k-3]  - spectmp[ 2]) +
            COEF3 * (-prev[k-6] +prev[k+5]  -spectmp[k-6] +spectmp[k+5]) +
            COEF4 * (-prev[k-7] +prev[k+6]  -spectmp[k-7] +spectmp[k+6]) +
            COEF5 * ( prev[k-10] -prev[k+9]  +spectmp[k-10] -spectmp[k+9]);

        im= COEF1 * ( prev[k-1] +prev[k]  +spectmp[k-1] +spectmp[k]) +
            COEF2 * (-prev[k-4] -prev[k+3]  -spectmp[k-4] -spectmp[k+3]) +
            COEF3 * (-prev[k-5] -prev[k+4]  -spectmp[k-5] -spectmp[k+4]) +
            COEF4 * ( prev[k-8] +prev[k+7]  +spectmp[k-8] +spectmp[k+7]) +
            COEF5 * ( prev[k-9] +prev[k+8]  +spectmp[k-9] +spectmp[k+8]);

        spec[j]   = 0.707106781186547524400844362104849 * (re + im);
        spec[j+1] = 0.707106781186547524400844362104849 * (im - re);
        spec[j+4] = prev[k] + spectmp[k+1];
        spec[j+5] = prev[k+1] - spectmp[k];

        j += 8;
        k += 2;

        re= COEF1 * ( prev[k-2] -prev[k+1]  -spectmp[k-2] +spectmp[k+1]) +
            COEF2 * ( prev[k-3] -prev[k+2]  -spectmp[k-3] +spectmp[k+2]) +
            COEF3 * (-prev[k-6] +prev[k+5]  +spectmp[k-6] -spectmp[k+5]) +
            COEF4 * (-prev[k-7] +prev[k+6]  +spectmp[k-7] -spectmp[k+6]) +
            COEF5 * ( prev[k-10] -prev[k+9]  -spectmp[k-10] +spectmp[k+9]);

        im= COEF1 * ( prev[k-1] +prev[k]  -spectmp[k-1] -spectmp[k]) +
            COEF2 * (-prev[k-4] -prev[k+3]  +spectmp[k-4] +spectmp[k+3]) +
            COEF3 * (-prev[k-5] -prev[k+4]  +spectmp[k-5] +spectmp[k+4]) +
            COEF4 * ( prev[k-8] +prev[k+7]  -spectmp[k-8] -spectmp[k+7]) +
            COEF5 * ( prev[k-9] +prev[k+8]  -spectmp[k-9] -spectmp[k+8]);

        spec[j]   = 0.707106781186547524400844362104849 * (re + im);
        spec[j+1] = 0.707106781186547524400844362104849 * (im - re);
        spec[j+4] = prev[k] - spectmp[k+1];
        spec[j+5] = prev[k+1] + spectmp[k];

    }


    for (i = 0; i < n + 4*FLTLEN; i++) prev[i] = spectmp[i];

    for (i = 0; i < MINBIN; i++) spec[4*i + 2] = spec[4*i + 3] =0.0;

    for (i = 4*MINBIN, totalpower = 0; i < (n-2)*4; i += 4) {
        float re = spec[i] - 0.5 * (spec[i-8] + spec[i+8]);
        float im = spec[i+1] - 0.5 * (spec[i-7] + spec[i+9]);
        spec[i+3] = (totalpower += (spec[i+2] = re * re + im * im));
    }

    if (totalpower > 1.0e-9) {
        totaldb = (float)DBSCAL * logf(totalpower/n);
        totalloudness = (float)sqrtf((float)sqrtf(totalpower));
        if (totaldb < 0) totaldb = 0;
    }
    else totaldb = totalloudness = 0.0;

    p->dbs[count] = totaldb + DBOFFSET;

    if (totaldb >= p->amplo) {
        npeak = 0;

        for (i = 4*MINBIN;i < (4*(n-2)) && npeak < numpks; i+=4) {
            float height = spec[i+2], h1 = spec[i-2], h2 = spec[i+6];
            float totalfreq, peakfr, tmpfr1, tmpfr2, m, var, stdev;

            if (height < h1 || height < h2 ||
            h1 < 0.00001*totalpower ||
            h2 < 0.00001*totalpower) continue;

            peakfr= ((spec[i-8] - spec[i+8]) * (2.0 * spec[i] -
                                        spec[i+8] - spec[i-8]) +
             (spec[i-7] - spec[i+9]) * (2.0 * spec[i+1] -
                                        spec[i+9] - spec[i-7])) /
            (height + height);
            tmpfr1=  ((spec[i-12] - spec[i+4]) *
              (2.0 * spec[i-4] - spec[i+4] - spec[i-12]) +
              (spec[i-11] - spec[i+5]) * (2.0 * spec[i-3] -
                                          spec[i+5] - spec[i-11])) /
            (2.0 * h1) - 1;
            tmpfr2= ((spec[i-4] - spec[i+12]) * (2.0 * spec[i+4] -
                                         spec[i+12] - spec[i-4]) +
             (spec[i-3] - spec[i+13]) * (2.0 * spec[i+5] -
                                         spec[i+13] - spec[i-3])) /
            (2.0 * h2) + 1;


            m = 0.333333333333 * (peakfr + tmpfr1 + tmpfr2);
            var = 0.5 * ((peakfr-m)*(peakfr-m) +
                     (tmpfr1-m)*(tmpfr1-m) + (tmpfr2-m)*(tmpfr2-m));

            totalfreq = (i>>2) + m;
            if (var * totalpower > THRSH * height
            || var < 1.0e-30) continue;

            stdev = (float)sqrt((float)var);
            if (totalfreq < 4) totalfreq = 4;


            peaklist[npeak].pwidth = stdev;
            peaklist[npeak].ppow = height;
            peaklist[npeak].ploudness = sqrt(sqrt(height));
            peaklist[npeak].pfreq = totalfreq;
            npeak++;
        }

          if (npeak > numpks) npeak = numpks;
          for (i = 0; i < maxbin; i++) histogram[i] = 0;
          for (i = 0; i < npeak; i++) {
            float pit = (float)(BPEROOVERLOG2 * logf(peaklist[i].pfreq) - 96.0);
            float binbandwidth = FACTORTOBINS * peaklist[i].pwidth/peaklist[i].pfreq;
            float putbandwidth = (binbandwidth < 2.0 ? 2.0 : binbandwidth);
            float weightbandwidth = (binbandwidth < 1.0 ? 1.0 : binbandwidth);
            float weightamp = 4.0 * peaklist[i].ploudness / totalloudness;
            for (j = 0; j < NPARTIALONSET; j++) {
              float bin = pit - partialonset[j];
              if (bin < maxbin) {
                float para, pphase, score = 30.0 * weightamp /
                  ((j+p->npartial) * weightbandwidth);
                int firstbin = bin + 0.5 - 0.5 * putbandwidth;
                int lastbin = bin + 0.5 + 0.5 * putbandwidth;
                int ibw = lastbin - firstbin;
                if (firstbin < -BINGUARD) break;
                para = 1.0 / (putbandwidth * putbandwidth);
                for (k = 0, pphase = firstbin-bin; k <= ibw;
                     k++,pphase += 1.0)
                  histogram[k+firstbin] += score * (1.0 - para * pphase * pphase);

              }
            }
          }


        for (best = 0, indx = -1, j=0; j < maxbin; j++) {
            if (histogram[j] > best) {
                indx = j;
                best = histogram[j];
            }
        }

        histpeak.hvalue = best;
        histpeak.hindex = indx;

        putfreq = expf((1.0 / BPEROOVERLOG2) * (histpeak.hindex + 96.0));

        for (j = 0; j < npeak; j++) {
            float fpnum = peaklist[j].pfreq/putfreq;
            int pnum = (int)(fpnum + 0.5);
            float fipnum = pnum;
            float deviation;
            if (pnum > 16 || pnum < 1) continue;
            deviation = 1.0 - fpnum/fipnum;
            if (deviation > -PARTIALDEVIANCE && deviation < PARTIALDEVIANCE) {
                float stdev, weight;
                npartials++;
                if (pnum < 8) nbelow8++;
                cumpow += peaklist[j].ppow;
                cumstrength += sqrt(sqrt(peaklist[j].ppow));
                stdev = (peaklist[j].pwidth > MINBW ?
                   peaklist[j].pwidth : MINBW);
                weight = 1.0 / ((stdev*fipnum) * (stdev*fipnum));
                freqden += weight;
                freqnum += weight * peaklist[j].pfreq/fipnum;
            }
        }
        if ((nbelow8 < 4 || npartials < 7) && cumpow < 0.01 * totalpower) {
            histpeak.hvalue = 0;
        } else {
            float pitchpow = (cumstrength * cumstrength);
            float freqinbins = freqnum/freqden;
            pitchpow = pitchpow * pitchpow;

            if (freqinbins < MINFREQINBINS) {
                histpeak.hvalue = 0;
            } else {
                p->cps = histpeak.hpitch = hzperbin * freqnum/freqden;
                histpeak.hloud = DBSCAL * logf(pitchpow/n);
            }
        }
    }
}
