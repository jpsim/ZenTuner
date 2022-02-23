import SwiftUI

extension HorizontalAlignment {
    private enum NoteCenter: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[HorizontalAlignment.center]
        }
    }

    static let noteCenter = HorizontalAlignment(NoteCenter.self)

    private enum OctaveCenter: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[HorizontalAlignment.center]
        }
    }

    static let octaveCenter = HorizontalAlignment(OctaveCenter.self)
}

extension VerticalAlignment {
    private enum NoteTickCenter: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }

    static let noteTickCenter = VerticalAlignment(NoteTickCenter.self)
}

extension Alignment {
    static let noteModifier = Alignment(horizontal: .octaveCenter, vertical: .top)
}
