// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

#ifndef ZENTUNER_H
#define ZENTUNER_H

#include <stdint.h>

typedef struct {
    float *utbl;
    int16_t *BRLow;
    int16_t *BRLowCpx;
} zt_fft;

void ffts1(float *ioptr, int M, float *Utbl, int16_t *BRLow, float sqrttwo);

#endif
