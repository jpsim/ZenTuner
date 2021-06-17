// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFoundation
import CMicrophonePitchDetector

/// Tap to do pitch tracking on any node.
final class PitchTap {
    // MARK: - Properties

    private var bufferSize: UInt32 { 4_096 }
    private let input: Node
    private var tracker: PitchTrackerRef?
    private let handler: (Float) -> Void

    // MARK: - Starting

    /// Enable the tap on input
    func start() {
        input.avAudioNode.removeTap(onBus: 0)
        input.avAudioNode
            .installTap(onBus: 0, bufferSize: bufferSize, format: nil) { [weak self] buffer, _ in
                self?.analyzePitch(buffer: buffer)
            }
    }

    // MARK: - Lifecycle

    /// Initialize the pitch tap
    ///
    /// - Parameters:
    ///   - input: Node to analyze
    ///   - handler: Callback to call when a pitch is detected
    init(_ input: Node, handler: @escaping (Float) -> Void) {
        self.input = input
        self.handler = handler
    }

    deinit {
        if let tracker = self.tracker {
            ztPitchTrackerDestroy(tracker)
        }
    }

    // MARK: - Private

    private func analyzePitch(buffer: AVAudioPCMBuffer) {
        buffer.frameLength = bufferSize
        guard let floatData = buffer.floatChannelData else { return }

        let tracker: PitchTrackerRef
        if let existingTracker = self.tracker {
            tracker = existingTracker
        } else {
            tracker = ztPitchTrackerCreate(UInt32(buffer.format.sampleRate), Int32(bufferSize), 20)
            self.tracker = tracker
        }

        ztPitchTrackerAnalyze(tracker, floatData[0], bufferSize)
        var amp: Float = 0
        var pitch: Float = 0
        ztPitchTrackerGetResults(tracker, &amp, &pitch)

        if amp > 0.1 {
            self.handler(pitch)
        }
    }
}
