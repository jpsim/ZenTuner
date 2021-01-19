import AudioKit
import AVFoundation
import SwiftUI

final class TunerController: ObservableObject {
    private let engine = AudioEngine()
    private var hasMicrophoneAccess = false
    private var tracker: PitchTap!

    @Published var data = TunerData()
    @Published var showMicrophoneAccessAlert = false

    init() {
        self.checkMicrophoneAuthorizationStatus()
    }

    func start() {
        guard hasMicrophoneAccess else { return }
        Settings.audioInputEnabled = true
        do {
            try engine.start()
            tracker.start()
        } catch {
            Log(error)
        }
    }

    func stop() {
        guard hasMicrophoneAccess else { return }
        engine.stop()
        Settings.audioInputEnabled = false
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
        Settings.bufferLength = .short

#if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setPreferredIOBufferDuration(Settings.bufferLength.duration)
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
        } catch {
            Log(error)
        }
#endif

        let input = engine.input!
        engine.output = Fader(Mixer(input), gain: 0)
        tracker = PitchTap(input) { pitch, amplitude in
            if amplitude[0] > 0.1 {
                DispatchQueue.main.async {
                    self.data = TunerData(pitch: pitch[0], amplitude: amplitude[0])
                }
            }
        }

        hasMicrophoneAccess = true
        start()
    }
}
