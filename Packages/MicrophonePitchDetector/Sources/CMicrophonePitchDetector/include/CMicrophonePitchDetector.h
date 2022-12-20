// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

#ifndef ZENTUNER_H
#define ZENTUNER_H

#include <stdint.h>
#include <stdio.h>

#ifndef ZTFLOAT
#define ZTFLOAT float
#endif

typedef struct {
    size_t size;
    void *ptr;
} zt_auxdata;

typedef struct {
    ZTFLOAT *out;
    int sr;
    unsigned long len;
    unsigned long pos;
} zt_data;

void zt_auxdata_alloc(zt_auxdata *aux, size_t size);
void zt_auxdata_free(zt_auxdata *aux);

void zt_create(zt_data **spp);
void zt_destroy(zt_data **spp);

typedef struct {
    ZTFLOAT *utbl;
    int16_t *BRLow;
    int16_t *BRLowCpx;
} zt_fft;

void zt_fft_create(zt_fft **fft);
void zt_fft_init(zt_fft *fft, int M);
void zt_fft_cpx(zt_fft *fft, ZTFLOAT *buf, int FFTsize);
void zt_fft_destroy(zt_fft *fft);

typedef struct {
    ZTFLOAT freq, amp;
    ZTFLOAT size;
    zt_auxdata signal, prev, sin, spec1, spec2, peakarray;
    int numpks;
    int cnt;
    int histcnt;
    int hopsize;
    ZTFLOAT sr;
    ZTFLOAT cps;
    ZTFLOAT dbs[20];
    ZTFLOAT amplo;
    ZTFLOAT npartial;
    ZTFLOAT dbfs;
    zt_fft fft;
} zt_ptrack;

void zt_ptrack_create(zt_ptrack **p);
void zt_ptrack_destroy(zt_ptrack **p);
void zt_ptrack_init(zt_data *sp, zt_ptrack *p, int ihopsize, int ipeaks);
void zt_ptrack_compute(zt_data *sp, zt_ptrack *p, ZTFLOAT *in, ZTFLOAT *freq, ZTFLOAT *amp);

#endif
