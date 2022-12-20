// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

#ifndef ZENTUNER_H
#define ZENTUNER_H

#include <stdint.h>

typedef struct {
    size_t size;
    void *ptr;
} zt_auxdata;

typedef struct peak
{
  float pfreq;
  float pwidth;
  float ppow;
  float ploudness;
} PEAK;

typedef struct {
    float *utbl;
    int16_t *BRLow;
    int16_t *BRLowCpx;
} zt_fft;

void zt_fft_cpx(zt_fft *fft, float *buf, int FFTsize);

typedef struct {
    float freq, amp;
    float size;
    zt_auxdata signal, prev, sin, spec1, spec2, peakarray;
    int numpks;
    int cnt;
    int histcnt;
    int hopsize;
    float sr;
    float cps;
    float dbs[20];
    float amplo;
    zt_fft fft;
} zt_ptrack;

typedef struct histopeak
{
  float hpitch;
  float hvalue;
  float hloud;
  int hindex;
} HISTOPEAK;

void ptrack_set_spec(zt_ptrack *p);
void ptrack_pt2(int *npeak, int numpks, PEAK *peaklist, float totalpower, float *spec, int n);
void ptrack_pt3(int npeak, int numpks, PEAK *peaklist, float maxbin, float *histogram, float totalloudness, float partialonset[], int partialonset_count);
void ptrack_pt4(HISTOPEAK *histpeak, float maxbin, float *histogram);
void ptrack_pt5(HISTOPEAK histpeak, int npeak, PEAK *peaklist, int *npartials, int *nbelow8, float *cumpow, float *cumstrength, float *freqnum, float *freqden);
void ptrack_pt6(zt_ptrack *p, int nbelow8, int npartials, float totalpower, HISTOPEAK *histpeak, float cumpow, float cumstrength, float freqnum, float freqden, int n);

#endif
