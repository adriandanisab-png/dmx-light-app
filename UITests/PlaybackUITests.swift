import XCTest

final class PlaybackUITests: DMXUITestCase {
    func testRecallLightsButtonAndBlackoutKey() throws {
        addRGBFixtures(count: 2)
        recordRedSnapshot(named: "Red wash")
        // Clear the programmer so playback is what drives the frame.
        element("clearProgrammer").click()

        openTab("Playback")
        let button = element("playbackButton.Red wash")
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForValue("off", of: button))
        button.click()
        XCTAssertTrue(waitForValue("on", of: button))
        XCTAssertTrue(element("fadeTimeField").waitForExistence(timeout: 5), "fade time is editable on this page")
        XCTAssertTrue(element("playbackStagePreview").exists, "the stage preview is visible while playing back")

        app.typeKey("b", modifierFlags: [])
        let blackout = element("blackoutButton")
        XCTAssertTrue(waitForValue("on", of: blackout))

        // Preview-only mode with blackout: the rendered frame is all zero (debug value on the status bar).
        let status = element("outputStatus")
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        let zero = NSPredicate(format: "value == %@", "frameSum=0")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: zero, object: status)], timeout: 5), .completed)
    }

    /// Faders are slider-backed accessibility elements; synthetic drags don't reach SwiftUI gestures on CI.
    func testFaderBanks() throws {
        addRGBFixtures(count: 2)
        recordRedSnapshot(named: "Red wash")
        element("clearProgrammer").click()
        openTab("Playback")

        let picker = element("faderBankPicker")
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        let snapshotsBank = app.radioButtons["Snapshots"].firstMatch
        if snapshotsBank.exists { snapshotsBank.click() }
        let fader = element("snapshotFader.Red wash")
        XCTAssertTrue(fader.waitForExistence(timeout: 5))
        XCTAssertEqual(text(of: fader), "0 %")
        fader.adjust(toNormalizedSliderPosition: 0.6)
        let raised = NSPredicate(format: "value != %@", "0 %")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: raised, object: fader)], timeout: 5), .completed)
        let status = element("outputStatus")
        let lit = NSPredicate(format: "value != %@", "frameSum=0")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: lit, object: status)], timeout: 5), .completed)
        XCTAssertTrue(waitForValue("on", of: element("playbackButton.Red wash")), "the fader activates the snapshot")

        let fixtures = app.radioButtons["Fixtures"].firstMatch
        XCTAssertTrue(fixtures.waitForExistence(timeout: 5))
        fixtures.click()
        let first = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'fixtureFader.'")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let before = text(of: first)
        first.adjust(toNormalizedSliderPosition: 0.8)
        let changed = NSPredicate(format: "value != %@", before)
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: changed, object: first)], timeout: 5), .completed)
    }
}
