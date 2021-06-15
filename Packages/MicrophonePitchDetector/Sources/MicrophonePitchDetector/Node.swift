// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFoundation

/// Node in an audio graph.
protocol Node: AnyObject {
    /// Nodes providing audio input to this node.
    var connections: [Node] { get }

    /// Internal AVAudioEngine node.
    var avAudioNode: AVAudioNode { get }
}

extension Node {
    func detach() {
        if let engine = avAudioNode.engine {
            engine.detach(avAudioNode)
        }
        for connection in connections {
            connection.detach()
        }
    }

    func disconnectAV() {
        if let engine = avAudioNode.engine {
            engine.disconnectNodeInput(avAudioNode)
            for connection in connections {
                connection.disconnectAV()
            }
        }
    }

    /// Work-around for an AVAudioEngine bug.
    func initLastRenderTime() {
        // We don't have a valid lastRenderTime until we query it.
        _ = avAudioNode.lastRenderTime

        for connection in connections {
            connection.initLastRenderTime()
        }
    }

    func makeAVConnections() {
        if let node = self as? HasInternalConnections {
            node.makeInternalConnections()
        }

        // Are we attached?
        if let engine = avAudioNode.engine {
            for (bus, connection) in connections.enumerated() {
                if let sourceEngine = connection.avAudioNode.engine {
                    if sourceEngine != avAudioNode.engine {
                        Log("🛑 Error: Attempt to connect nodes from different engines.")
                        return
                    }
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

    var bypassed: Bool {
        get { avAudioNode.auAudioUnit.shouldBypassEffect }
        set { avAudioNode.auAudioUnit.shouldBypassEffect = newValue }
    }

    /// Start the node
    func start() { bypassed = false }
    /// Stop the node
    func stop() { bypassed = true }
    /// Play the node
    func play() { bypassed = false }
    /// Bypass the node
    func bypass() { bypassed = true }
}

protocol HasInternalConnections: AnyObject {
    /// Override point for any connections internal to the node.
    func makeInternalConnections()
}
