import AVFoundation

enum MicrophoneAccess {
    enum Status {
        case granted
        case denied
    }

    static func getOrRequestPermission() async -> Status {
        if #available(iOS 17.0, macOS 14.0, watchOS 10.0, xrOS 1.0, *) {
            let recordPermission = AVAudioApplication.shared.recordPermission
            return switch recordPermission {
            case .undetermined: await AVAudioApplication.requestRecordPermission() ? .granted : .denied
            case .granted: .granted
            case .denied: .denied
            @unknown default: .denied
            }
        }

#if os(watchOS)
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(with: .success(granted ? .granted : .denied))
            }
        }
#elseif !os(xrOS)
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        return switch authorizationStatus {
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .audio) ? .granted : .denied
        case .authorized: .granted
        case .denied, .restricted: .denied
        @unknown default: .denied
        }
#endif
    }
}
