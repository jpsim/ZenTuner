import XCTest
@testable import ZenTuner

class TranspositionTests: XCTestCase {
    func testBFlatTranspositions() {
        struct NoteAndOctave: Hashable {
            let note: ScaleNote
            let octave: Int

            init(_ note: ScaleNote, _ octave: Int) {
                self.note = note
                self.octave = octave
            }
        }

        let bFlatTranspositions: [NoteAndOctave: NoteAndOctave] = [
            .init(.C, 4):
                .init(.D, 4),
            .init(.CSharp_DFlat, 4):
                .init(.DSharp_EFlat, 4),
            .init(.D, 4):
                .init(.E, 4),
            .init(.DSharp_EFlat, 4):
                .init(.F, 4),
            .init(.E, 4):
                .init(.FSharp_GFlat, 4),
            .init(.F, 4):
                .init(.G, 4),
            .init(.FSharp_GFlat, 4):
                .init(.GSharp_AFlat, 4),
            .init(.G, 4):
                .init(.A, 4),
            .init(.GSharp_AFlat, 4):
                .init(.ASharp_BFlat, 4),
            .init(.A, 4):
                .init(.B, 4),
            .init(.ASharp_BFlat, 4):
                .init(.C, 5),
            .init(.B, 4):
                .init(.CSharp_DFlat, 5)
        ]

        for (input, transposition) in bFlatTranspositions {
            XCTAssertEqual(
                ScaleNote.Match(note: input.note, octave: input.octave, distance: 0).inTransposition(.ASharp_BFlat),
                ScaleNote.Match(note: transposition.note, octave: transposition.octave, distance: 0)
            )
        }
    }
}
