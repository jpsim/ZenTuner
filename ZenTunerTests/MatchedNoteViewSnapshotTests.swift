import SnapshotTesting
import SwiftUI
import UIKit
import XCTest
@testable import ZenTuner

final class MatchedNoteViewSnapshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        diffTool = "ksdiff"
    }

    func testMatchedNoteView() {
        let view = MatchedNoteView(
            match: ScaleNote.Match(
                note: .ASharp_BFlat,
                octave: 4,
                distance: 0
            ),
            modifierPreference: .preferSharps
        )

        assertSnapshot(matching: view, as: .image(layout: .device(config: .iPhone8)))
    }
}
