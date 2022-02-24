// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFoundation

/// Tap to do pitch tracking on any node.
final class PitchTap {
    // MARK: - Properties

    private var bufferSize: UInt32 { 4_096 }
    private let input: Node
    private var tracker: PitchTracker?
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

    // MARK: - Private

    private func analyzePitch(buffer: AVAudioPCMBuffer) {
        buffer.frameLength = bufferSize
        guard let floatData = buffer.floatChannelData else { return }

        let tracker: PitchTracker
        if let existingTracker = self.tracker {
            tracker = existingTracker
        } else {
            tracker = PitchTracker(
                sampleRate: Int32(buffer.format.sampleRate),
                hopSize: Int32(bufferSize),
                peakCount: 20
            )
            self.tracker = tracker
        }

        let frames = (0..<Int(bufferSize)).map { floatData[0].advanced(by: $0) }
        if let pitch = tracker.getPitch(frames: frames) {
            self.handler(pitch)
        }
    }
}
