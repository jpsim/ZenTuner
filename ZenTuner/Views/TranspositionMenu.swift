import SwiftUI

struct TranspositionMenu: View {
    private let transpositions = ScaleNote.allCases
    @Binding var selectedTransposition: Int

    var body: some View {
        Menu(
            content: {
                ForEach(transpositions) { transposition in
                    Button(
                        action: {
                            selectedTransposition = transposition.rawValue
                        },
                        label: {
                            Text(transposition.transpositionName)
                        }
                    )
                }
            },
            label: {
                Text(transpositions[selectedTransposition].transpositionName)
                    // Increase tap area, some of the transpositions are just a single
                    // letter so the tap area can otherwise be quite small.
                    .frame(minWidth: 100, alignment: .leading)
            }
        )
        .transaction { transaction in
            // Disable jarring animation when menu label changes width
            transaction.disablesAnimations = true
            transaction.animation = nil
        }
    }
}

private extension ScaleNote {
    var transpositionName: String {
        switch self {
        case .C: "Concert Pitch"
        default: names.joined(separator: " / ")
        }
    }
}

struct TranspositionMenu_Previews: PreviewProvider {
    static var previews: some View {
        TranspositionMenu(selectedTransposition: .constant(0))
            .previewLayout(.sizeThatFits)
    }
}
