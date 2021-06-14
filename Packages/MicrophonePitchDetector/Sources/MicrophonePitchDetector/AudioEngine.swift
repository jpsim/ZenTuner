// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFoundation

extension AVAudioNode {
    /// Disconnect without breaking other connections.
    func disconnect(input: AVAudioNode) {
        guard let engine = engine else { return }

        var newConnections: [AVAudioNode: [AVAudioConnectionPoint]] = [:]
        for bus in 0 ..< numberOfInputs {
            if let cp = engine.inputConnectionPoint(for: self, inputBus: bus), cp.node === input {
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

    /// Input for microphone or other device is created when this is accessed
    /// If adjusting AudioKit.Settings, do so before setting up the microphone.
    /// Setting the .defaultToSpeaker option in AudioKit.Settings.session.setCategory after setting up your mic
    /// can cause the AVAudioEngine to stop running.
    var input: InputNode? {
        if #available(macOS 10.14, *) {
            guard Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") != nil else {
                Log("To use the microphone, you must include the NSMicrophoneUsageDescription in your Info.plist", type: .error)
                return nil
            }
        }
        if _input.isNotConnected {
            _input.connect(to: self)
            _input.isNotConnected = false
        }
        return _input
    }

    /// Empty initializer
    init() {}

    /// Output node
    var output: Node? {
        didSet {
            // AVAudioEngine doesn't allow the outputNode to be changed while the engine is running
            let wasRunning = avEngine.isRunning
            if wasRunning { stop() }

            // remove the exisiting node if it is present
            if let node = oldValue {
                mainMixerNode?.removeInput(node)
                node.detach()
                avEngine.outputNode.disconnect(input: node.avAudioNode)
            }

            // if non nil, set the main output now
            if let node = output {
                avEngine.attach(node.avAudioNode)

                // create the on demand mixer if needed
                createEngineMixer()
                mainMixerNode?.addInput(node)
                mainMixerNode?.makeAVConnections()
            }

            if wasRunning { try? start() }
        }
    }

    // simulate the AVAudioEngine.mainMixerNode, but create it ourselves to ensure the
    // correct sample rate is used from .stereo
    private func createEngineMixer() {
        guard mainMixerNode == nil else { return }

        let mixer = Mixer()
        avEngine.attach(mixer.avAudioNode)
        avEngine.connect(mixer.avAudioNode, to: avEngine.outputNode, format: .stereo)
        mainMixerNode = mixer
    }

    private func removeEngineMixer() {
        guard let mixer = mainMixerNode else { return }
        avEngine.outputNode.disconnect(input: mixer.avAudioNode)
        mixer.removeAllInputs()
        mixer.detach()
        mainMixerNode = nil
    }

    /// Start the engine
    func start() throws {
        if output == nil {
            Log("🛑 Error: Attempt to start engine with no output.")
            return
        }
        try avEngine.start()
    }

    /// Stop the engine
    func stop() {
        avEngine.stop()
    }
}

private extension AVAudioFormat {
    static var stereo: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2) ??
            AVAudioFormat()
    }
}
