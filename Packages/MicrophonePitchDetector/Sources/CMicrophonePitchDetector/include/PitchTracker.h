// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

#pragma once

#ifdef __cplusplus
#define ZT_API extern "C"
#else
#define ZT_API
#endif

typedef struct PitchTracker *PitchTrackerRef;

ZT_API PitchTrackerRef ztPitchTrackerCreate(unsigned int sampleRate, int hopSize, int peakCount);
ZT_API void ztPitchTrackerDestroy(PitchTrackerRef);

ZT_API void ztPitchTrackerAnalyze(PitchTrackerRef tracker, float* frames, unsigned int count);
ZT_API void ztPitchTrackerGetResults(PitchTrackerRef tracker, float* trackedAmplitude, float* trackedFrequency);
