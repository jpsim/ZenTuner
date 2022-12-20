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
#define THRSH 10

float get_peakfr(float *spec, float height, int i)
{
    return ((spec[i-8] - spec[i+8]) * (2.0 * spec[i] - spec[i+8] - spec[i-8]) +
            (spec[i-7] - spec[i+9]) * (2.0 * spec[i+1] - spec[i+9] - spec[i-7])) / (height + height);
}

float get_tmpfr1(float *spec, float h1, int i)
{
    return ((spec[i-12] - spec[i+4]) * (2.0 * spec[i-4] - spec[i+4] - spec[i-12]) +
            (spec[i-11] - spec[i+5]) * (2.0 * spec[i-3] - spec[i+5] - spec[i-11])) / (2.0 * h1) - 1;
}

float get_tmpfr2(float *spec, float h2, int i)
{
    return ((spec[i-4] - spec[i+12]) * (2.0 * spec[i+4] - spec[i+12] - spec[i-4]) +
            (spec[i-3] - spec[i+13]) * (2.0 * spec[i+5] - spec[i+13] - spec[i-3])) / (2.0 * h2) + 1;
}
