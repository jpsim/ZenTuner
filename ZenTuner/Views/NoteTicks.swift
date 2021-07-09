import SwiftUI

struct NoteTicks: View {
    let tunerData: TunerData
    let showFrequencyText: Bool

    var body: some View {
        NoteDistanceMarkers()
            .overlay(
                CurrentNoteMarker(
                    frequency: tunerData.pitch,
                    distance: tunerData.closestNote.distance,
                    showFrequencyText: showFrequencyText
                )
            )
    }
}
