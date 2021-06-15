// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFoundation
import CMicrophonePitchDetector

/// Tap to do pitch tracking on any node.
/// start() will add the tap, and stop() will remove it.
final class PitchTap {
    // MARK: - Properties

    /// Size of buffer to analyze
    private var bufferSize: UInt32 { 4_096 }

    /// Tells whether the node is processing (ie. started, playing, or active)
    private var isStarted = false

    /// The bus to install the tap onto
    private var bus: Int = 0 {
        didSet {
            if isStarted {
                stop()
                start()
            }
        }
    }

    /// Input node to analyze
    private let input: Node

    private var pitch: [Float] = [0, 0]
    private var amp: [Float] = [0, 0]
    private var trackers: [PitchTrackerRef] = []
    private var unfairLock = os_unfair_lock_s()

    /// Callback type
    typealias Handler = ([Float], [Float]) -> Void
    private var handler: Handler = { _, _ in }

    // MARK: - Starting & Stopping

    /// Enable the tap on input
    func start() {
        lock()
        defer {
            unlock()
        }
        guard !isStarted else { return }
        isStarted = true

        // a node can only have one tap at a time installed on it
        // make sure any previous tap is removed.
        // We're making the assumption that the previous tap (if any)
        // was installed on the same bus as our bus var.
        removeTap()

        input.avAudioNode
            .installTap(onBus: bus, bufferSize: bufferSize, format: nil) { [weak self] buffer, _ in
                self?.handleTapBlock(buffer: buffer)
            }
    }

    /// Stop detecting pitch
    func stop() {
        lock()
        removeTap()
        isStarted = false
        unlock()
        for idx in 0 ..< pitch.count {
            pitch[idx] = 0.0
        }
    }

    // MARK: - Lifecycle

    /// Initialize the pitch tap
    ///
    /// - Parameters:
    ///   - input: Node to analyze
    ///   - handler: Callback to call on each analysis pass
    init(_ input: Node, handler: @escaping Handler) {
        self.input = input
        self.handler = handler
    }

    deinit {
        for tracker in trackers {
            ztPitchTrackerDestroy(tracker)
        }
    }

    // MARK: - Private

    /// Handle new buffer data
    /// - Parameters:
    ///   - buffer: Buffer to analyze
    ///   - time: Unused in this case
    private func handleTapBlock(buffer: AVAudioPCMBuffer) {
        // Call on the main thread so the client doesn't have to worry
        // about thread safety.
        buffer.frameLength = bufferSize
        DispatchQueue.main.async {
            // Create trackers as needed.
            self.lock()
            guard self.isStarted == true else {
                self.unlock()
                return
            }
            self.analyzePitch(buffer: buffer)
            self.unlock()
        }
    }

    private func removeTap() {
        input.avAudioNode.removeTap(onBus: bus)
    }

    private func lock() {
        os_unfair_lock_lock(&unfairLock)
    }

    private func unlock() {
        os_unfair_lock_unlock(&unfairLock)
    }

    private func analyzePitch(buffer: AVAudioPCMBuffer) {
        guard let floatData = buffer.floatChannelData else { return }
        let channelCount = Int(buffer.format.channelCount)
        let length = UInt(buffer.frameLength)
        while self.trackers.count < channelCount {
            self.trackers.append(ztPitchTrackerCreate(UInt32(buffer.format.sampleRate), 4_096, 20))
        }

        while self.amp.count < channelCount {
            self.amp.append(0)
            self.pitch.append(0)
        }

        for channel in 0 ..< channelCount {
            let data = floatData[channel]

            ztPitchTrackerAnalyze(self.trackers[channel], data, UInt32(length))

            var amp: Float = 0
            var pitch: Float = 0
            ztPitchTrackerGetResults(self.trackers[channel], &amp, &pitch)
            self.amp[channel] = amp
            self.pitch[channel] = pitch
        }
        self.handler(self.pitch, self.amp)
    }
}
