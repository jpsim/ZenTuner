import SwiftUI

struct TranspositionMenu: View {
    private let transpositions = ScaleNote.allCases.map(\.transpositionName)
    @Binding var selectedTransposition: Int

    var body: some View {
        Menu(
            content: {
                ForEach(0..<transpositions.count) { index in
                    Button(
                        action: {
                            selectedTransposition = index
                        },
                        label: {
                            Text(transpositions[index])
                        }
                    )
                }
            },
            label: {
                Text(transpositions[selectedTransposition])
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
        case .C:
            return "Concert Pitch"
        default:
            return names.joined(separator: " / ")
        }
    }
}

struct TranspositionMenu_Previews: PreviewProvider {
    static var previews: some View {
        TranspositionMenu(selectedTransposition: .constant(0))
            .previewLayout(.sizeThatFits)
    }
}
