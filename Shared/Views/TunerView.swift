import SwiftUI

struct TunerView: View {
    @ObservedObject var tunerController = TunerController()
    @AppStorage("modifierPreference") var modifierPreference = ModifierPreference.preferSharps

    private var tunerData: TunerData { tunerController.data }

    var body: some View {
        VStack(alignment: .noteCenter) {
            MatchedNoteView(
                match: tunerData.closestNote,
                modifierPreference: modifierPreference
            )
            .onTapGesture {
                modifierPreference = modifierPreference.toggled
            }
            MatchedNoteFrequency(frequency: tunerData.closestNote.frequency)
            NoteDistanceMarkers()
                .overlay(
                    CurrentNoteMarker(
                        frequency: tunerData.pitch,
                        distance: tunerData.closestNote.distance
                    )
                )
        }
        .onAppear(perform: tunerController.start)
        .onDisappear(perform: tunerController.stop)
        .alert(isPresented: $tunerController.showMicrophoneAccessAlert) {
            Alert(
                title: Text("No microphone access"),
                message: Text(
                    """
                    Please grant microphone access in the Settings app in the "Privacy ⇾ Microphone" section.
                    """),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct TunerView_Previews: PreviewProvider {
    static var previews: some View {
        TunerView()
    }
}
