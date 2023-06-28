// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFoundation

/// AudioKit version of Apple's Mixer Node. Mixes a variadic list of Nodes.
class Mixer {
    let auMixer = AVAudioMixerNode()

    /// Initialize the mixer node with no inputs, to be connected later
    init() {}

    /// Add input to the mixer
    ///
    /// - parameter node: Node to add
    func addInput(_ node: Mixer) {
        guard let engine = auMixer.engine else { return }
        engine.attach(node.auMixer)
        auMixer.connectMixer(input: node.auMixer)
        auMixer.outputVolume = 0
    }
}
