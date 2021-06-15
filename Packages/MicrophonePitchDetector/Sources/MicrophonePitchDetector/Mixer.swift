// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFoundation

/// AudioKit version of Apple's Mixer Node. Mixes a variadic list of Nodes.
class Mixer: Node {
    private var inputs: [Node] = []

    /// Connected nodes
    var connections: [Node] { inputs }

    private let auMixer = AVAudioMixerNode()

    /// Underlying AVAudioNode
    var avAudioNode: AVAudioNode { auMixer }

    /// Initialize the mixer node with no inputs, to be connected later
    init() {}

    /// Add input to the mixer
    /// - Parameter node: Node to add
    func addInput(_ node: Node) {
        assert(!hasInput(node), "Node is already connected to Mixer.")
        inputs.append(node)
        makeAVConnections()
    }

    /// Is this node already connected?
    /// - Parameter node: Node to check
    private func hasInput(_ node: Node) -> Bool {
        connections.contains(where: { $0 === node })
    }

    /// Remove input from the mixer
    /// - Parameter node: Node to remove
    func removeInput(_ node: Node) {
        inputs.removeAll(where: { $0 === node })
        avAudioNode.disconnect(input: node.avAudioNode)
    }

    /// Remove all inputs from the mixer
    func removeAllInputs() {
        guard !connections.isEmpty else { return }

        let nodes = connections.map { $0.avAudioNode }
        for input in nodes {
            avAudioNode.disconnect(input: input)
        }
        inputs.removeAll()
    }

    func silenceOutput() {
        auMixer.outputVolume = 0
    }
}

private extension Node {
    func makeAVConnections() {
        // Are we attached?
        guard let engine = avAudioNode.engine else {
            return
        }

        for (bus, connection) in connections.enumerated() {
            if let sourceEngine = connection.avAudioNode.engine, sourceEngine != avAudioNode.engine {
                assertionFailure("Attempt to connect nodes from different engines.")
                return
            }

            engine.attach(connection.avAudioNode)

            // Mixers will decide which input bus to use.
            if let mixer = avAudioNode as? AVAudioMixerNode {
                mixer.connectMixer(input: connection.avAudioNode)
            } else {
                avAudioNode.connect(input: connection.avAudioNode, bus: bus)
            }

            connection.makeAVConnections()
        }
    }
}
