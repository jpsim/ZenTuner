// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

#ifndef ZENTUNER_H
#define ZENTUNER_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdio.h>
#include "PitchTracker.h"

#ifndef ZTFLOAT
#define ZTFLOAT float
#endif
#define ZT_OK 1
#define ZT_NOT_OK 0

typedef struct zt_auxdata {
    size_t size;
    void *ptr;
} zt_auxdata;

typedef struct zt_data {
    ZTFLOAT *out;
    int sr;
    int nchan;
    unsigned long len;
    unsigned long pos;
    char filename[200];
    uint32_t rand;
} zt_data;

int zt_auxdata_alloc(zt_auxdata *aux, size_t size);
int zt_auxdata_free(zt_auxdata *aux);

int zt_create(zt_data **spp);
int zt_destroy(zt_data **spp);

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
    ZTFLOAT asig,size,peak;
    zt_auxdata signal, prev, sin, spec1, spec2, peakarray;
    int numpks;
    int cnt;
    int histcnt;
    int hopsize;
    ZTFLOAT sr;
    ZTFLOAT cps;
    ZTFLOAT dbs[20];
    ZTFLOAT amplo;
    ZTFLOAT amphi;
    ZTFLOAT npartial;
    ZTFLOAT dbfs;
    ZTFLOAT prevf;
    zt_fft fft;
} zt_ptrack;

int zt_ptrack_create(zt_ptrack **p);
int zt_ptrack_destroy(zt_ptrack **p);
int zt_ptrack_init(zt_data *sp, zt_ptrack *p, int ihopsize, int ipeaks);
int zt_ptrack_compute(zt_data *sp, zt_ptrack *p, ZTFLOAT *in, ZTFLOAT *freq, ZTFLOAT *amp);

#ifdef __cplusplus
}
#endif

#endif
