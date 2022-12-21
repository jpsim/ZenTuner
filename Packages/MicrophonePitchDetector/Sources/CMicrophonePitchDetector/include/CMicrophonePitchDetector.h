// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

#ifndef ZENTUNER_H
#define ZENTUNER_H

#include <stdint.h>

void bitrevR2(float *ioptr, int M, int16_t *BRLow);
void bfR2(float *ioptr, int M, int NDiffU);
void bfR4(float *ioptr, int M, int NDiffU, float sqrttwo);
void bfstages(float *ioptr, int M, float *Utbl, int Ustride, int NDiffU, int StageCnt);

#endif
