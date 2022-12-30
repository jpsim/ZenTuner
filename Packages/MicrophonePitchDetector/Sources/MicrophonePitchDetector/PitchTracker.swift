import AVFoundation
import ZenPTrack

public final class PitchTracker {
    private var ptrack: ZenPTrack

    public static var defaultBufferSize: UInt32 { 4_096 }

    public init(
        sampleRate: Double,
        hopSize: Double = Double(PitchTracker.defaultBufferSize),
        peakCount: Int = 20
    ) {
        ptrack = ZenPTrack(sampleRate: sampleRate, hopSize: hopSize, peakCount: peakCount)
    }

    public func getPitch(from buffer: AVAudioPCMBuffer, amplitudeThreshold: Double = 0.1) -> Double? {
        guard let floatData = buffer.floatChannelData else { return nil }

        var pitch = 0.0
        var amplitude = 0.0

        let floatBuffer = UnsafeBufferPointer(start: floatData[0], count: Int(buffer.frameLength))
        for float in floatBuffer {
            ptrack.compute(
                bufferValue: float,
                pitch: &pitch,
                amplitude: &amplitude
            )
        }

        if amplitude > amplitudeThreshold, pitch > 0 {
            return pitch
        } else {
            return nil
        }
    }
}
