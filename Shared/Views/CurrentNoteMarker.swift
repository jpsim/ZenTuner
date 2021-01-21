import SwiftUI

struct CurrentNoteMarker: View {
    let frequency: Frequency
    let distance: Frequency.MusicalDistance
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center) {
                Rectangle()
                    .frame(width: 4, height: NoteTickSize.large.height)
                    .cornerRadius(4)
                    .foregroundColor(distance.isPerceptible ? .red : .green)
                Text(frequency.localizedString())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: geometry.size.width)
            .offset(
                x: (geometry.size.width / 2) * CGFloat(distance.cents / 50)
            )
            .animation(.easeInOut)
        }
    }
}

struct CurrentNoteMarker_Previews: PreviewProvider {
    static var previews: some View {
        CurrentNoteMarker(frequency: 440.0, distance: 0)
            .previewLayout(.fixed(width: 300, height: 200))
    }
}
