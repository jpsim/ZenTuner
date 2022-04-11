import AVFoundation
import SwiftUI
#if os(watchOS)
import WatchKit
#endif

public final class MicrophonePitchDetector: ObservableObject {
    private let engine = AudioEngine()
    private var hasMicrophoneAccess = false
    private var tracker: PitchTap!

    @Published public var pitch: Float = 440
    @Published public var showMicrophoneAccessAlert = false

    public init() {
        self.checkMicrophoneAuthorizationStatus()
    }

    public func start() {
        guard hasMicrophoneAccess else { return }
        do {
            try engine.start()
            tracker.start()
        } catch {
            // TODO: Handle error
        }
    }

    public func stop() {
        guard hasMicrophoneAccess else { return }
        do {
            try engine.stop()
        } catch {
            // TODO: Handle error
        }
    }

    // MARK: - Private

    private func checkMicrophoneAuthorizationStatus() {
        guard !hasMicrophoneAccess else { return }

#if os(watchOS)
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if granted {
                self.setUpPitchTracking()
            } else {
                self.showMicrophoneAccessAlert = true
            }
        }
#else
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: // The user has previously granted access to the microphone.
            self.setUpPitchTracking()
        case .notDetermined: // The user has not yet been asked for microphone access.
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    self.setUpPitchTracking()
                } else {
                    self.showMicrophoneAccessAlert = true
                    return
                }
            }
        case .denied: // The user has previously denied access.
            self.showMicrophoneAccessAlert = true
            return
        case .restricted: // The user can't grant access due to restrictions.
            self.showMicrophoneAccessAlert = true
            return
        @unknown default:
            self.showMicrophoneAccessAlert = true
            return
        }
#endif
    }

    private func setUpPitchTracking() {
        tracker = PitchTap(engine.input) { pitch in
            DispatchQueue.main.async {
                self.pitch = pitch
            }
        }

        hasMicrophoneAccess = true
        start()
    }
}
