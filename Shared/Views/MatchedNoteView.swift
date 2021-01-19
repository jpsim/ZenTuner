import SwiftUI

struct MatchedNoteView: View {
    let match: ScaleNote.Match
    let modifierPreference: ModifierPreference
    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            MainNoteView(note: note)
            VStack(alignment: .leading) {
                if let modifier = modifier {
                    Text(modifier)
                        // TODO: Avoid hardcoding size
                        .font(.system(size: 50, design: .rounded))
                        .foregroundColor(.red)
                    Spacer()
                        .frame(height: 24) // TODO: Fix this with alignment guides
                }
                Text("\(match.octave)")
                    // TODO: Avoid hardcoding size
                    .font(.system(size: 40, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var preferredName: String {
        switch modifierPreference {
        case .preferSharps:
            return match.note.names.first!
        case .preferFlats:
            return match.note.names.last!
        }
    }

    private var note: String {
        return String(preferredName.prefix(1))
    }

    private var modifier: String? {
        return preferredName.count > 1 ?
            String(preferredName.suffix(1)) :
            nil
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
