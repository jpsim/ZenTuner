import SwiftUI

struct MatchedNoteView: View {
    let match: ScaleNote.Match
    @State var modifierPreference: ModifierPreference

    var body: some View {
        ZStack(alignment: .noteModifier) {
            HStack(alignment: .lastTextBaseline) {
                MainNoteView(note: note)
                    .animation(nil, value: note) // Don't animate text frame
                    .animatingPerceptibleForegroundColor(isPerceptible: match.distance.isPerceptible)
                Text(String(describing: match.octave))
                    .alignmentGuide(.octaveCenter) { dimensions in
                        dimensions[HorizontalAlignment.center]
                    }
                    // TODO: Avoid hardcoding size
                    .font(.system(size: 40, design: .rounded))
                    .foregroundColor(.secondary)
            }

            if let modifier = modifier {
                Text(modifier)
                    // TODO: Avoid hardcoding size
                    .font(.system(size: 50, design: .rounded))
                    .baselineOffset(-30) // TODO: Find a better way to align top of text - FB9267771
                    .animatingPerceptibleForegroundColor(isPerceptible: match.distance.isPerceptible)
                    .alignmentGuide(.octaveCenter) { dimensions in
                        dimensions[HorizontalAlignment.center]
                    }
            }
        }
        .animation(.easeInOut, value: match.distance.isPerceptible)
        .onTapGesture {
            modifierPreference = modifierPreference.toggled
        }
    }

    private var preferredName: String {
        switch modifierPreference {
        case .preferSharps:
            match.note.names.first!
        case .preferFlats:
            match.note.names.last!
        }
    }

    private var note: String {
        String(preferredName.prefix(1))
    }

    private var modifier: String? {
        preferredName.count > 1 ?
            String(preferredName.suffix(1)) :
            nil
    }
}

private extension View {
    @ViewBuilder
    func animatingPerceptibleForegroundColor(isPerceptible: Bool) -> some View {
        self
            .foregroundColor(isPerceptible ? .perceptibleMusicalDistance : .imperceptibleMusicalDistance)
    }
}

struct MatchedNoteView_Previews: PreviewProvider {
    static var previews: some View {
        MatchedNoteView(
            match: ScaleNote.Match(
                note: .ASharp_BFlat,
                octave: 4,
                distance: 0
            ),
            modifierPreference: .preferSharps
        )
        .previewLayout(.sizeThatFits)
    }
}
