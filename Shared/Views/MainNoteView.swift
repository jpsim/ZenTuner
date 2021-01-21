import SwiftUI

struct MainNoteView: View {
    let note: String
    let color: Color
    var body: some View {
        Text(note)
            .font(.system(size: 160, design: .rounded))
            .bold()
            .foregroundColor(color)
            .alignmentGuide(.noteCenter) { dimensions in
                dimensions[HorizontalAlignment.center]
            }
    }
}

struct MainNoteView_Previews: PreviewProvider {
    static var previews: some View {
        MainNoteView(note: "A", color: .red)
            .previewLayout(.sizeThatFits)
    }
}
