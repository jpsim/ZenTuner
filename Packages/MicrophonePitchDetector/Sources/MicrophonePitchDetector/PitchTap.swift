// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFoundation

/// Tap to do pitch tracking on any node.
final class PitchTap {
    // MARK: - Properties

    private var bufferSize: UInt32 { PitchTracker.defaultBufferSize }
    private let input: AVAudioMixerNode
    private var tracker: PitchTracker?
    private let handler: (Double) -> Void
    private let didReceiveAudio: () -> Void

    // MARK: - Starting

    /// Enable the tap on input
    func start() {
        input.installTap(onBus: 0, bufferSize: bufferSize, format: nil) { [weak self] buffer, _ in
            self?.analyzePitch(buffer: buffer)
        }
    }

    // MARK: - Lifecycle

    /// Initialize the pitch tap
    ///
    /// - Parameters:
    ///   - input: Node to analyze
    ///   - handler: Callback to call when a pitch is detected
    ///   - didReceiveAudio: Callback to call when any audio is detected
    init(_ input: AVAudioMixerNode, handler: @escaping (Double) -> Void, didReceiveAudio: @escaping () -> Void) {
        self.input = input
        self.handler = handler
        self.didReceiveAudio = didReceiveAudio
    }

    // MARK: - Private

    private func analyzePitch(buffer: AVAudioPCMBuffer) {
        buffer.frameLength = bufferSize
        didReceiveAudio()

        if tracker == nil {
            tracker = PitchTracker(sampleRate: buffer.format.sampleRate)
        }

        if let pitch = tracker?.getPitch(from: buffer) {
            self.handler(pitch)
        }
    }
}
