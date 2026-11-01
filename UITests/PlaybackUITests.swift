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

        app.typeKey("b", modifierFlags: [])
        let blackout = element("blackoutButton")
        XCTAssertTrue(waitForValue("on", of: blackout))

        // Preview-only mode with blackout: the rendered frame is all zero (debug value on the status bar).
        let status = element("outputStatus")
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        let zero = NSPredicate(format: "value == %@", "frameSum=0")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: zero, object: status)], timeout: 5), .completed)
    }
}
