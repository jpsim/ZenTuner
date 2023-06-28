import AVFoundation
import SwiftUI
#if os(watchOS)
import WatchKit
#endif

public final class MicrophonePitchDetector: ObservableObject {
    private let engine = AudioEngine()
    private var hasMicrophoneAccess = false
    private var tracker: PitchTap!

    @Published public var pitch: Double = 440
    @Published public var didReceiveAudio = false
    @Published public var showMicrophoneAccessAlert = false

    public init() {}

    @MainActor
    public func activate(debug: Bool = false) async throws {
        let startDate = Date()
        var intervalMS: UInt64 = 30

        while !didReceiveAudio {
            if debug {
                print("Waiting \(intervalMS * 2)ms")
            }
            try? await Task.sleep(nanoseconds: intervalMS * NSEC_PER_MSEC)
            try await checkMicrophoneAuthorizationStatus()
            try? await Task.sleep(nanoseconds: intervalMS * NSEC_PER_MSEC)
            try start()
            intervalMS = min(intervalMS * 2, 180)
        }

        if debug {
            let duration = String(format: "%.2fs", -startDate.timeIntervalSinceNow)
            print("Took \(duration) to start")
        }
    }

    // MARK: - Private

    private func start() throws {
        guard hasMicrophoneAccess else { return }
        try engine.start()
        tracker.start()
    }

    @MainActor
    private func checkMicrophoneAuthorizationStatus() async throws {
        guard !hasMicrophoneAccess else { return }

        switch await MicrophoneAccess.getOrRequestPermission() {
        case .granted:
            try await setUpPitchTracking()
        case .denied:
            showMicrophoneAccessAlert = true
        }
    }

    private func setUpPitchTracking() async throws {
        tracker = PitchTap(engine.input, handler: { pitch in
            Task { @MainActor in
                self.pitch = pitch
            }
        }, didReceiveAudio: {
            Task { @MainActor in
                self.didReceiveAudio = true
            }
        })

        hasMicrophoneAccess = true
        try start()
    }
}
