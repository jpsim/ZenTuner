// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

#ifndef ZENTUNER_H
#define ZENTUNER_H

#include <stdint.h>

void bfR2(float *ioptr, int M, int NDiffU);
void bfR4(float *ioptr, int M, int NDiffU, float sqrttwo);

#endif
