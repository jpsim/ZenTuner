// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFoundation

extension AVAudioNode {
    /// Disconnect without breaking other connections.
    func disconnect(input: AVAudioNode) {
        guard let engine = engine else { return }

        var newConnections: [AVAudioNode: [AVAudioConnectionPoint]] = [:]
        for bus in 0 ..< numberOfInputs {
            if let connectionPoint = engine.inputConnectionPoint(for: self, inputBus: bus),
               connectionPoint.node === input
            {
                let points = engine.outputConnectionPoints(for: input, outputBus: 0)
                newConnections[input] = points.filter { $0.node != self }
            }
        }

        for (node, connections) in newConnections {
            if connections.isEmpty {
                engine.disconnectNodeOutput(node)
            } else {
                engine.connect(node, to: connections, fromBus: 0, format: .stereo)
            }
        }
    }

    /// Make a connection without breaking other connections.
    func connect(input: AVAudioNode, bus: Int) {
        guard let engine = engine else { return }

        var points = engine.outputConnectionPoints(for: input, outputBus: 0)
        if points.contains(where: { $0.node === self && $0.bus == bus }) {
            return
        }

        points.append(AVAudioConnectionPoint(node: self, bus: bus))
        engine.connect(input, to: points, fromBus: 0, format: .stereo)
    }
}

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
#if os(iOS)
    private let session = AVAudioSession.sharedInstance()
#endif

    /// Main mixer at the end of the signal chain
    private var mainMixerNode: Mixer?

    /// Input node mixer
    class InputNode: Mixer {
        var isNotConnected = true

        func connect(to engine: AudioEngine) {
            engine.avEngine.attach(avAudioNode)
            engine.avEngine.connect(engine.avEngine.inputNode, to: avAudioNode, format: nil)
        }
    }

    private let _input = InputNode()

    /// Input for microphone is created when this is accessed
    var input: InputNode {
        if _input.isNotConnected {
            _input.connect(to: self)
            _input.isNotConnected = false
            self.createSilentOutput()
        }
        return _input
    }

    /// Empty initializer
    init() {}

    /// Start the engine
    func start() throws {
        try avEngine.start()
#if os(iOS)
        try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers])
        try session.setActive(true)
#endif
    }

    /// Stop the engine
    func stop() throws {
        avEngine.stop()
#if os(iOS)
        try session.setActive(false)
#endif
    }

    // MARK: - Private

    private func createSilentOutput() {
        let output = _input
        avEngine.attach(output.avAudioNode)

        // create the on demand mixer if needed
        createEngineMixer()
        mainMixerNode?.addInput(output)
    }

    // simulate the AVAudioEngine.mainMixerNode, but create it ourselves to ensure the
    // correct sample rate is used from .stereo
    private func createEngineMixer() {
        guard mainMixerNode == nil else { return }

        let mixer = Mixer()
        avEngine.attach(mixer.avAudioNode)
        avEngine.connect(mixer.avAudioNode, to: avEngine.outputNode, format: .stereo)
        mainMixerNode = mixer
        mixer.silenceOutput()
    }
}

private extension AVAudioFormat {
    static var stereo: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2) ??
            AVAudioFormat()
    }
}

private extension Node {
    func detach() {
        if let engine = avAudioNode.engine {
            engine.detach(avAudioNode)
        }
        for connection in connections {
            connection.detach()
        }
    }
}
