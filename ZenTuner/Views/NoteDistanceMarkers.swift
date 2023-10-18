import SwiftUI

struct NoteDistanceMarkers: View {
    var body: some View {
        HStack {
            ForEach(0..<25) { index in
                Rectangle()
                    .frame(width: 1, height: tickSize(forIndex: index).height)
                    .cornerRadius(1)
                    .foregroundColor(.secondary)
                    .inExpandingRectangle()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .alignmentGuide(.noteTickCenter) { dimensions in
            dimensions[VerticalAlignment.center]
        }
    }

    private func tickSize(forIndex index: Int) -> NoteTickSize {
        switch index {
        case 12:           .large
        case 2, 7, 17, 22: .medium
        default:           .small
        }
    }
}

enum NoteTickSize {
    case small, medium, large

    var height: CGFloat {
        switch self {
        case .small:  60
        case .medium: 100
        case .large:  180
        }
    }
}

extension View {
    func inExpandingRectangle() -> some View {
        ZStack {
            Rectangle()
                .foregroundColor(.clear)
            self
        }
    }
}

struct NoteDistanceMarkers_Previews: PreviewProvider {
    static var previews: some View {
        NoteDistanceMarkers()
            .previewLayout(.sizeThatFits)
    }
}
