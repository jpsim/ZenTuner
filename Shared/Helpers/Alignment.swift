import SwiftUI

extension HorizontalAlignment {
    enum NoteCenter: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[HorizontalAlignment.center]
        }
    }

    static let noteCenter = HorizontalAlignment(NoteCenter.self)
}

extension VerticalAlignment {
    enum NoteTickCenter: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }

    static let noteTickCenter = VerticalAlignment(NoteTickCenter.self)
}
