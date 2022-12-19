import MicrophonePitchDetector
import SwiftUI

struct TunerScreen: View {
    @ObservedObject private var pitchDetector = MicrophonePitchDetector()
    @AppStorage("modifierPreference") private var modifierPreference = ModifierPreference.preferSharps
    @AppStorage("selectedTransposition") private var selectedTransposition = 0

    var body: some View {
        TunerView(
            tunerData: TunerData(pitch: pitchDetector.pitch),
            modifierPreference: modifierPreference,
            selectedTransposition: selectedTransposition
        )
        .task {
            await pitchDetector.activate()
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
