// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

#include "PitchTracker.h"
#include "CMicrophonePitchDetector.h"

struct PitchTracker {
    zt_data *sp = nullptr;
    zt_ptrack *ptrack = nullptr;

    PitchTracker(size_t sampleRate, int hopSize, int peakCount) {
        zt_create(&sp);
        sp->sr = (int)sampleRate;
        sp->nchan = 1;

        zt_ptrack_create(&ptrack);
        zt_ptrack_init(sp, ptrack, hopSize, peakCount);
    }

    ~PitchTracker() {
        zt_ptrack_destroy(&ptrack);
        zt_destroy(&sp);
    }

    void analyze(float* frames, size_t count) {
        for(int i = 0; i < count; ++i) {
            zt_ptrack_compute(sp, ptrack, frames + i, &trackedFrequency, &trackedAmplitude);
        }
    }

    float trackedAmplitude = 0.0;
    float trackedFrequency = 0.0;
};

ZT_API PitchTrackerRef ztPitchTrackerCreate(unsigned int sampleRate, int hopSize, int peakCount) {
    return new PitchTracker(sampleRate, hopSize, peakCount);
}

ZT_API void ztPitchTrackerDestroy(PitchTrackerRef tracker) {
    delete tracker;
}

ZT_API void ztPitchTrackerAnalyze(PitchTrackerRef tracker, float* frames, unsigned int count) {
    tracker->analyze(frames, count);
}

ZT_API void ztPitchTrackerGetResults(PitchTrackerRef tracker, float* trackedAmplitude, float* trackedFrequency) {
    *trackedAmplitude = tracker->trackedAmplitude;
    *trackedFrequency = tracker->trackedFrequency;
}
