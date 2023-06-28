// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFoundation

extension AVAudioMixerNode {
    /// Make a connection without breaking other connections.
    func connectMixer(input: AVAudioNode) {
        guard let engine = engine else { return }

        var points = engine.outputConnectionPoints(for: input, outputBus: 0)
        if points.contains(where: { $0.node === self }) {
            return
        }

        points.append(AVAudioConnectionPoint(node: self, bus: nextAvailableInputBus))
        engine.connect(input, to: points, fromBus: 0, format: .stereo)
    }
}

/// AudioKit's wrapper for AVAudioEngine
final class AudioEngine {
    /// Internal AVAudioEngine
    private let avEngine = AVAudioEngine()

    /// Input node mixer
    private final class Input: Mixer {
        var isNotConnected = true

        func connect(to engine: AudioEngine) {
            engine.avEngine.attach(auMixer)
            engine.avEngine.connect(engine.avEngine.inputNode, to: auMixer, format: nil)
        }
    }

    private let _input = Input()

    /// Input for microphone is created when this is accessed
    var inputMixer: AVAudioMixerNode {
        if _input.isNotConnected {
            _input.connect(to: self)
            _input.isNotConnected = false
            self.createSilentOutput()
        }
        return _input.auMixer
    }

    /// Empty initializer
    init() {}

    /// Start the engine
    func start() throws {
        try avEngine.start()
    }

#if !os(macOS)
    /// Configures the audio session
    func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        let bufferDuration = 7 / AVAudioFormat.stereo.sampleRate
#if !os(watchOS)
        try session.setPreferredIOBufferDuration(bufferDuration)
        try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers])
#endif
        try session.setActive(true)
    }
#endif

    // MARK: - Private

    private func createSilentOutput() {
        let output = _input
        avEngine.attach(output.auMixer)

        // create the on demand mixer if needed
        createEngineMixer(input: output)
    }

    // simulate the AVAudioEngine.mainMixerNode, but create it ourselves to ensure the
    // correct sample rate is used from .stereo
    private func createEngineMixer(input: Mixer) {
        let mixer = Mixer()
        avEngine.attach(mixer.auMixer)
        avEngine.connect(mixer.auMixer, to: avEngine.outputNode, format: .stereo)
        mixer.addInput(input)
    }
}

private extension AVAudioFormat {
    static var stereo: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2) ??
            AVAudioFormat()
    }
}
