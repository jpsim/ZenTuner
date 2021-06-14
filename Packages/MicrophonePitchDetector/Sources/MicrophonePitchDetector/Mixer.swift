// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFoundation

/// AudioKit version of Apple's Mixer Node. Mixes a variadic list of Nodes.
class Mixer: Node {
    /// The internal mixer node
    fileprivate let mixerAU = AVAudioMixerNode()

    var inputs: [Node] = []
    
    /// Connected nodes
    var connections: [Node] { inputs }

    /// Underlying AVAudioNode
    var avAudioNode: AVAudioNode

    /// Output Volume (Default 1), values above 1 will have gain applied
    var volume: AUValue = 1.0 {
        didSet {
            volume = max(volume, 0)
            mixerAU.outputVolume = volume
        }
    }

    /// Initialize the mixer node with no inputs, to be connected later
    init() {
        avAudioNode = mixerAU
    }

    /// Add input to the mixer
    /// - Parameter node: Node to add
    func addInput(_ node: Node) {
        guard !hasInput(node) else {
            Log("🛑 Error: Node is already connected to Mixer.")
            return
        }
        inputs.append(node)
        makeAVConnections()
    }

    /// Is this node already connected?
    /// - Parameter node: Node to check
    func hasInput(_ node: Node) -> Bool {
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
}
