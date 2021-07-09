import MicrophonePitchDetector
import SwiftUI

struct TunerScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var pitchDetector = MicrophonePitchDetector()
    @AppStorage("modifierPreference") private var modifierPreference = ModifierPreference.preferSharps
    @AppStorage("selectedTransposition") private var selectedTransposition = 0

    var body: some View {
        TunerView(
            tunerData: TunerData(pitch: pitchDetector.pitch),
            modifierPreference: modifierPreference,
            selectedTransposition: selectedTransposition
        )
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                pitchDetector.start()
            case .inactive, .background:
                pitchDetector.stop()
            @unknown default:
                pitchDetector.stop()
            }
        }
        .alert(isPresented: $pitchDetector.showMicrophoneAccessAlert) {
            MicrophoneAccessAlert()
        }
    }
}

struct TunerScreen_Previews: PreviewProvider {
    static var previews: some View {
        TunerScreen()
    }
}
