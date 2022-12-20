// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

#ifndef ZENTUNER_H
#define ZENTUNER_H

#include <stdint.h>
#include <stdio.h>

typedef struct {
    size_t size;
    void *ptr;
} zt_auxdata;

typedef struct {
    float *out;
    int sr;
    unsigned long len;
    unsigned long pos;
} zt_data;

typedef struct {
    float *utbl;
    int16_t *BRLow;
    int16_t *BRLowCpx;
} zt_fft;

void zt_fft_create(zt_fft **fft);
void zt_fft_init(zt_fft *fft, int M);
void zt_fft_cpx(zt_fft *fft, float *buf, int FFTsize);
void zt_fft_destroy(zt_fft *fft);

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
    float npartial;
    zt_fft fft;
} zt_ptrack;

void zt_ptrack_init(zt_data *sp, zt_ptrack *p, int ihopsize, int ipeaks, float pi);
void ptrack(zt_data *sp, zt_ptrack *p);

#endif
