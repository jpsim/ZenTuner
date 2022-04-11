import Darwin.C.math
import SwiftUI

/// A note in a twelve-tone equal temperament scale. https://en.wikipedia.org/wiki/Equal_temperament
enum ScaleNote: Int, CaseIterable, Identifiable {
    case C, CSharp_DFlat, D, DSharp_EFlat, E, F, FSharp_GFlat, G, GSharp_AFlat, A, ASharp_BFlat, B

    var id: Int { rawValue }

    /// A note match given an input frequency.
    struct Match: Hashable {
        /// The matched note.
        let note: ScaleNote
        /// The octave of the matched note.
        let octave: Int
        /// The distance between the input frequency and the matched note's defined frequency.
        let distance: Frequency.MusicalDistance

        /// The frequency of the matched note, adjusted by octave.
        var frequency: Frequency { note.frequency.shifted(byOctaves: octave) }

        /// The current note match adjusted for transpositions.
        ///
        /// - parameter transposition: The transposition on which to map the current match.
        ///
        /// - returns: The match mapped to the specified transposition.
        func inTransposition(_ transposition: ScaleNote) -> ScaleNote.Match {
            let transpositionDistanceFromC = transposition.rawValue
            guard transpositionDistanceFromC > 0 else {
                return self
            }

            let currentNoteIndex = note.rawValue
            let allNotes = ScaleNote.allCases
            let noteOffset = (allNotes.count - transpositionDistanceFromC) + currentNoteIndex
            let transposedNoteIndex = noteOffset % allNotes.count
            let transposedNote = allNotes[transposedNoteIndex]
            let octaveShift = (noteOffset > allNotes.count - 1) ? 1 : 0
            return ScaleNote.Match(
                note: transposedNote,
                octave: octave + octaveShift,
                distance: distance
            )
        }
    }

    /// Find the closest note to the specified frequency.
    ///
    /// - parameter frequency: The frequency to match against.
    ///
    /// - returns: The closest note match.
    static func closestNote(to frequency: Frequency) -> Match {
        // Shift frequency octave to be within range of scale note frequencies.
        var octaveShiftedFrequency = frequency

        while octaveShiftedFrequency > allCases.last!.frequency {
            octaveShiftedFrequency.shift(byOctaves: -1)
        }

        while octaveShiftedFrequency < allCases.first!.frequency {
            octaveShiftedFrequency.shift(byOctaves: 1)
        }

        // Find closest note
        let closestNote = allCases.min(by: { note1, note2 in
            fabsf(note1.frequency.distance(to: octaveShiftedFrequency).cents) <
                fabsf(note2.frequency.distance(to: octaveShiftedFrequency).cents)
        })!

        let octave = max(octaveShiftedFrequency.distanceInOctaves(to: frequency), 0)

        let fastResult = Match(
            note: closestNote,
            octave: octave,
            distance: closestNote.frequency.distance(to: octaveShiftedFrequency)
        )

        // Fast result can be incorrect at the scale boundary
        guard fastResult.note == .C && fastResult.distance.isFlat ||
                fastResult.note == .B && fastResult.distance.isSharp else
        {
            return fastResult
        }

        var match: Match?
        for octave in [octave, octave + 1] {
            for note in [ScaleNote.C, .B] {
                let distance = note.frequency.shifted(byOctaves: octave).distance(to: frequency)
                if let match = match, abs(distance.cents) > abs(match.distance.cents) {
                    return match
                } else {
                    match = Match(
                        note: note,
                        octave: octave,
                        distance: distance
                    )
                }
            }
        }

        assertionFailure("Closest note could not be found")
        return fastResult
    }

    /// The names for this note.
    var names: [String] {
        switch self {
        case .C:
            return ["C"]
        case .CSharp_DFlat:
            return ["C♯", "D♭"]
        case .D:
            return ["D"]
        case .DSharp_EFlat:
            return ["D♯", "E♭"]
        case .E:
            return ["E"]
        case .F:
            return ["F"]
        case .FSharp_GFlat:
            return ["F♯", "G♭"]
        case .G:
            return ["G"]
        case .GSharp_AFlat:
            return ["G♯", "A♭"]
        case .A:
            return ["A"]
        case .ASharp_BFlat:
            return ["A♯", "B♭"]
        case .B:
            return ["B"]
        }
    }

    /// The frequency for this note at the 0th octave in standard pitch: https://en.wikipedia.org/wiki/Standard_pitch
    var frequency: Frequency {
        switch self {
        case .C:
            return 16.35160
        case .CSharp_DFlat:
            return 17.32391
        case .D:
            return 18.35405
        case .DSharp_EFlat:
            return 19.44544
        case .E:
            return 20.60172
        case .F:
            return 21.82676
        case .FSharp_GFlat:
            return 23.12465
        case .G:
            return 24.49971
        case .GSharp_AFlat:
            return 25.95654
        case .A:
            return 27.5
        case .ASharp_BFlat:
            return 29.13524
        case .B:
            return 30.86771
        }
    }
}
