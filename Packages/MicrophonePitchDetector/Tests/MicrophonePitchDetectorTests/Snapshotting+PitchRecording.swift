import Foundation
import PitchRecording
import SnapshotTesting
import XCTest

extension SimplySnapshotting<PitchRecording> {
    static let pitchRecording = Snapshotting(
        pathExtension: "json",
        diffing: .pitchRecording
    )
}

private extension JSONEncoder {
    static let prettyPrinted: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}

private extension Diffing where Value == PitchRecording {
    static let pitchRecording = Diffing(
        // swiftlint:disable:next force_try
        toData: { try! JSONEncoder.prettyPrinted.encode($0) },
        // swiftlint:disable:next force_try
        fromData: { try! JSONDecoder().decode(PitchRecording.self, from: $0) }
    ) { old, new -> (String, [XCTAttachment])? in
        guard old.entries.count == new.entries.count else { return nil }

        let mismatchedEntries = zip(old.entries, new.entries).filter { old, new in
            !old.isApproximatelyEqual(to: new, pitchThreshold: 1)
        }

        if mismatchedEntries.isEmpty {
            return nil
        }

        let numberOfMismatchesToPrint = 5
        let mismatchDescriptions = mismatchedEntries.prefix(numberOfMismatchesToPrint).compactMap { entry in
            Snapshotting.lines.diffing.diff("\(entry.0)", "\(entry.1)")?.0
        }

        var messageSegments = [
            "Found \(mismatchedEntries.count) mismatched \(mismatchedEntries.count == 1 ? "entry" : "entries")."
        ]

        if mismatchedEntries.count > numberOfMismatchesToPrint {
            messageSegments.append("First \(numberOfMismatchesToPrint) mismatches are:")
        }

        messageSegments.append(contentsOf: mismatchDescriptions)

        let message = messageSegments.joined(separator: "\n")

        return (message, [])
    }
}
