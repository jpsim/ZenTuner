import XCTest
@testable import ZenTuner

class ClosestNoteTests: XCTestCase {
    func testClosestNote() {
        let measureOptions = XCTMeasureOptions.default
        measureOptions.iterationCount = 100
        measure(options: measureOptions) {
            for (note, octave, frequency) in kNoteTable {
                let justFrequency = Frequency(floatLiteral: frequency)
                let closestNote = ScaleNote.closestNote(to: justFrequency)
                XCTAssertEqual(closestNote.note, note)
                XCTAssertEqual(closestNote.octave, octave)
                XCTAssertFalse(closestNote.distance.isPerceptible)

                let slightlyFlat = ScaleNote.closestNote(to: justFrequency.adding(-12))
                XCTAssertEqual(slightlyFlat.note, note)
                XCTAssertEqual(slightlyFlat.octave, octave)
                XCTAssertTrue(slightlyFlat.distance.isFlat)
                XCTAssertTrue(slightlyFlat.distance.isPerceptible)

                let slightlySharp = ScaleNote.closestNote(to: justFrequency.adding(12))
                XCTAssertEqual(slightlySharp.note, note)
                XCTAssertEqual(slightlySharp.octave, octave)
                XCTAssertTrue(slightlySharp.distance.isSharp)
                XCTAssertTrue(slightlySharp.distance.isPerceptible)
            }
        }
    }
}

// From https://pages.mtu.edu/~suits/notefreqs.html
private let kNoteTable: [(note: ScaleNote, octave: Int, frequency: Double)] = [
    (.C, 0, 16.3),
    (.CSharp_DFlat, 0, 17.3),
    (.D, 0, 18.3),
    (.DSharp_EFlat, 0, 19.4),
    (.E, 0, 20.6),
    (.F, 0, 21.8),
    (.FSharp_GFlat, 0, 23.1),
    (.G, 0, 24.5),
    (.GSharp_AFlat, 0, 25.9),
    (.A, 0, 27.5),
    (.ASharp_BFlat, 0, 29.1),
    (.B, 0, 30.8),
    (.C, 1, 32.7),
    (.CSharp_DFlat, 1, 34.6),
    (.D, 1, 36.7),
    (.DSharp_EFlat, 1, 38.8),
    (.E, 1, 41.2),
    (.F, 1, 43.6),
    (.FSharp_GFlat, 1, 46.2),
    (.G, 1, 49.0),
    (.GSharp_AFlat, 1, 51.9),
    (.A, 1, 55.0),
    (.ASharp_BFlat, 1, 58.2),
    (.B, 1, 61.7),
    (.C, 2, 65.4),
    (.CSharp_DFlat, 2, 69.3),
    (.D, 2, 73.4),
    (.DSharp_EFlat, 2, 77.7),
    (.E, 2, 82.4),
    (.F, 2, 87.3),
    (.FSharp_GFlat, 2, 92.5),
    (.G, 2, 98.0),
    (.GSharp_AFlat, 2, 103.83),
    (.A, 2, 110.00),
    (.ASharp_BFlat, 2, 116.54),
    (.B, 2, 123.47),
    (.C, 3, 130.81),
    (.CSharp_DFlat, 3, 138.59),
    (.D, 3, 146.83),
    (.DSharp_EFlat, 3, 155.56),
    (.E, 3, 164.81),
    (.F, 3, 174.61),
    (.FSharp_GFlat, 3, 185.00),
    (.G, 3, 196.00),
    (.GSharp_AFlat, 3, 207.65),
    (.A, 3, 220.00),
    (.ASharp_BFlat, 3, 233.08),
    (.B, 3, 246.94),
    (.C, 4, 261.63),
    (.CSharp_DFlat, 4, 277.18),
    (.D, 4, 293.66),
    (.DSharp_EFlat, 4, 311.13),
    (.E, 4, 329.63),
    (.F, 4, 349.23),
    (.FSharp_GFlat, 4, 369.99),
    (.G, 4, 392.00),
    (.GSharp_AFlat, 4, 415.30),
    (.A, 4, 440.00),
    (.ASharp_BFlat, 4, 466.16),
    (.B, 4, 493.88),
    (.C, 5, 523.25),
    (.CSharp_DFlat, 5, 554.37),
    (.D, 5, 587.33),
    (.DSharp_EFlat, 5, 622.25),
    (.E, 5, 659.25),
    (.F, 5, 698.46),
    (.FSharp_GFlat, 5, 739.99),
    (.G, 5, 783.99),
    (.GSharp_AFlat, 5, 830.61),
    (.A, 5, 880.00),
    (.ASharp_BFlat, 5, 932.33),
    (.B, 5, 987.77),
    (.C, 6, 1046.5),
    (.CSharp_DFlat, 6, 1108.7),
    (.D, 6, 1174.6),
    (.DSharp_EFlat, 6, 1244.5),
    (.E, 6, 1318.5),
    (.F, 6, 1396.9),
    (.FSharp_GFlat, 6, 1479.9),
    (.G, 6, 1567.9),
    (.GSharp_AFlat, 6, 1661.2),
    (.A, 6, 1760.0),
    (.ASharp_BFlat, 6, 1864.6),
    (.B, 6, 1975.5),
    (.C, 7, 2093.0),
    (.CSharp_DFlat, 7, 2217.4),
    (.D, 7, 2349.3),
    (.DSharp_EFlat, 7, 2489.0),
    (.E, 7, 2637.0),
    (.F, 7, 2793.8),
    (.FSharp_GFlat, 7, 2959.9),
    (.G, 7, 3135.9),
    (.GSharp_AFlat, 7, 3322.4),
    (.A, 7, 3520.0),
    (.ASharp_BFlat, 7, 3729.3),
    (.B, 7, 3951.0),
    (.C, 8, 4186.0),
    (.CSharp_DFlat, 8, 4434.9),
    (.D, 8, 4698.6),
    (.DSharp_EFlat, 8, 4978.0),
    (.E, 8, 5274.0),
    (.F, 8, 5587.6),
    (.FSharp_GFlat, 8, 5919.9),
    (.G, 8, 6271.9),
    (.GSharp_AFlat, 8, 6644.8),
    (.A, 8, 7040.0),
    (.ASharp_BFlat, 8, 7458.6),
    (.B, 8, 7902.1)
]
