// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFoundation

/// AudioKit version of Apple's Mixer Node. Mixes a variadic list of Nodes.
class Mixer {
    private var inputs: [Mixer] = []

    /// Connected nodes
    var connections: [Mixer] { inputs }

    let auMixer = AVAudioMixerNode()

    /// Initialize the mixer node with no inputs, to be connected later
    init() {}

    /// Add input to the mixer
    /// - Parameter node: Node to add
    func addInput(_ node: Mixer) {
        assert(!hasInput(node), "Node is already connected to Mixer.")
        inputs.append(node)
        makeAVConnections()
    }

    /// Is this node already connected?
    /// - Parameter node: Node to check
    private func hasInput(_ node: Mixer) -> Bool {
        connections.contains(where: { $0 === node })
    }

    func silenceOutput() {
        auMixer.outputVolume = 0
    }
}

private extension Mixer {
    func makeAVConnections() {
        // Are we attached?
        guard let engine = auMixer.engine else {
            return
        }

        for connection in connections {
            if let sourceEngine = connection.auMixer.engine, sourceEngine != auMixer.engine {
                assertionFailure("Attempt to connect nodes from different engines.")
                return
            }

            engine.attach(connection.auMixer)
            auMixer.connectMixer(input: connection.auMixer)
            connection.makeAVConnections()
        }
    }
}
