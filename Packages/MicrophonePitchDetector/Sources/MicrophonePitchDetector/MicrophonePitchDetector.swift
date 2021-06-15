import AVFoundation
import SwiftUI

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
        engine.stop()
    }

    // MARK: - Private

    private func checkMicrophoneAuthorizationStatus() {
        guard !hasMicrophoneAccess else { return }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: // The user has previously granted access to the microphone.
            self.setUpAudioSession()
        case .notDetermined: // The user has not yet been asked for microphone access.
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    self.setUpAudioSession()
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
    }

    private func setUpAudioSession() {
#if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(true)
        } catch {
            // TODO: Handle error
        }
#endif

        tracker = PitchTap(engine.input) { pitch, amplitude in
            if amplitude[0] > 0.1 {
                DispatchQueue.main.async {
                    self.pitch = pitch[0]
                }
            }
        }

        hasMicrophoneAccess = true
        start()
    }
}
