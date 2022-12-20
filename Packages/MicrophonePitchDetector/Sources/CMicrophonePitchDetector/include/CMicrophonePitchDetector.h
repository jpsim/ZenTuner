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

void ptrack_set_spec_pt1(zt_ptrack *p);
void ptrack_set_spec_pt2(zt_ptrack *p);
void ptrack_set_spec_pt3(zt_ptrack *p);
void ptrack_set_spec_pt4(zt_ptrack *p);

void ptrack_pt2(int *npeak, int numpks, PEAK *peaklist, float totalpower, float *spec, int n);

#endif
