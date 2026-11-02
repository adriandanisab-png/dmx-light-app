import XCTest

final class DiagUITests: DMXUITestCase {
    func testDiagKeys() throws {
        addRGBFixtures(count: 2)
        recordRedSnapshot(named: "Red wash")
        element("clearProgrammer").click()
        openTab("Playback")
        let blackout = element("blackoutButton")
        XCTAssertTrue(blackout.waitForExistence(timeout: 5))
        var log: [String] = []
        func press(_ label: String) {
            let before = blackout.value as? String ?? "?"
            app.typeKey("b", modifierFlags: [])
            Thread.sleep(forTimeInterval: 1)
            log.append("\(label): \(before) -> \(blackout.value as? String ?? "?")")
        }
        press("A fresh")
        press("A again")
        element("tapTempoButton").click(); press("B after TAP click")
        element("playbackButton.Red wash").click(); press("C after snapshot click")
        element("effectPreset.Chase").click(); press("D after preset click")
        element("fadeTimeField").click(); press("E in fade field")
        XCTFail(log.joined(separator: " | "))
    }
}
