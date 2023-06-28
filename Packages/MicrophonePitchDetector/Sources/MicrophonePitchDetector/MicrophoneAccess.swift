import AVFoundation

enum MicrophoneAccess {
    enum Status {
        case granted
        case denied
    }

    static func getOrRequestPermission() async -> Status {
#if os(watchOS)
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(with: .success(granted ? .granted : .denied))
            }
        }
#else
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: // The user has previously granted access to the microphone.
            return .granted
        case .notDetermined: // The user has not yet been asked for microphone access.
            if await AVCaptureDevice.requestAccess(for: .audio) {
                return .granted
            } else {
                return .denied
            }
        case .denied: // The user has previously denied access.
            return .denied
        case .restricted: // The user can't grant access due to restrictions.
            return .denied
        @unknown default:
            return .denied
        }
#endif
    }
}
