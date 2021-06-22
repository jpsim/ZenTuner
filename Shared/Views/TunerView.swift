import MicrophonePitchDetector
import SwiftUI

struct TunerView: View {
    @ObservedObject private var pitchDetector = MicrophonePitchDetector()
    @AppStorage("modifierPreference") private var modifierPreference = ModifierPreference.preferSharps
    @AppStorage("selectedTransposition") private var selectedTransposition = 0

    private var tunerData: TunerData { TunerData(pitch: pitchDetector.pitch) }

    var body: some View {
        Group {
#if os(watchOS)
            ZStack(alignment: Alignment(horizontal: .noteCenter, vertical: .noteTickCenter)) {
                NoteDistanceMarkers()
                    .overlay(
                        CurrentNoteMarker(
                            frequency: tunerData.pitch,
                            distance: tunerData.closestNote.distance,
                            showFrequencyText: false
                        )
                    )

                MatchedNoteView(
                    match: tunerData.closestNote.inTransposition(ScaleNote.allCases[selectedTransposition]),
                    modifierPreference: modifierPreference
                )
                .onTapGesture {
                    modifierPreference = modifierPreference.toggled
                }
                .focusable()
                .digitalCrownRotation(
                    Binding(
                        get: { Float(selectedTransposition) },
                        set: { selectedTransposition = Int($0) }
                    ),
                    from: 0,
                    through: Float(ScaleNote.allCases.count - 1),
                    by: 1
                )
            }
#else
            VStack(alignment: .noteCenter) {
                HStack {
                    TranspositionMenu(selectedTransposition: $selectedTransposition)
                        .padding()

                    Spacer()
                }

                Spacer()

                MatchedNoteView(
                    match: tunerData.closestNote.inTransposition(ScaleNote.allCases[selectedTransposition]),
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
                            distance: tunerData.closestNote.distance,
                            showFrequencyText: true
                        )
                    )

                Spacer()
            }
#endif
        }
        .onAppear(perform: pitchDetector.start)
        .onDisappear(perform: pitchDetector.stop)
        .alert(isPresented: $pitchDetector.showMicrophoneAccessAlert) {
            Alert(
                title: Text("No microphone access"),
                message: Text(
                    """
                    Please grant microphone access in the Settings app in the "Privacy ⇾ Microphone" section.
                    """)
            )
        }
    }
}

struct TunerView_Previews: PreviewProvider {
    static var previews: some View {
        TunerView()
    }
}
