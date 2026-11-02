import XCTest

final class CueListUITests: DMXUITestCase {
    override var extraLaunchArguments: [String] { ["-useRecordingMIDI"] }

    /// Two RGB fixtures, one red snapshot playing, a new cue list open in its editor with two cues
    /// captured from the current look.
    private func buildListWithTwoCues() {
        addRGBFixtures(count: 2)
        recordRedSnapshot(named: "Red")
        element("clearProgrammer").click()
        openTab("Playback")
        let red = element("playbackButton.Red")
        XCTAssertTrue(red.waitForExistence(timeout: 5))
        red.click()
        XCTAssertTrue(waitForValue("on", of: red))

        openTab("Library")
        let new = element("newCueListButton")
        XCTAssertTrue(new.waitForExistence(timeout: 5))
        new.click()
        let add = element("addCueFromLook")
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.click()
        add.click()
        XCTAssertTrue(element("cueDirect.2").waitForExistence(timeout: 5))
    }

    private func closeEditor() {
        element("cueListDone").click()
    }

    func testGoAdvancesAndModeSwitchSkips() throws {
        buildListWithTwoCues()
        // Cue 1 gets a console backup, cue 2 does not.
        element("cueConsole.1").click()
        let state = app.menuItems["Current console state (0 cells)"]
        XCTAssertTrue(state.waitForExistence(timeout: 5))
        state.click()
        XCTAssertTrue(element("consoleBackupBanner").waitForExistence(timeout: 5), "cue 2 has no console backup")
        closeEditor()

        openTab("Playback")
        let go = element("cueGo")
        XCTAssertTrue(go.waitForExistence(timeout: 5))
        go.click()
        let current = element("cueCurrentNumber")
        XCTAssertTrue(waitForValue("1", of: current))
        XCTAssertEqual(text(of: current), "1")
        XCTAssertEqual(text(of: element("cueNextNumber")), "2")

        // Switch to Console mode: cue 2 has no console part, so GO skips it with a toast.
        openTab("Devices")
        let console = app.radioButtons["Console (MIDI)"].firstMatch
        XCTAssertTrue(console.waitForExistence(timeout: 5))
        console.click()
        openTab("Playback")
        XCTAssertTrue(element("cueGo").waitForExistence(timeout: 5))
        element("cueGo").click()
        let toast = element("toast")
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
        XCTAssertTrue(text(of: toast).contains("Skipped cue 2"), "toast was: \(text(of: toast))")
        XCTAssertEqual(text(of: element("cueCurrentNumber")), "1", "the current cue index is kept")
    }

    func testAutoFollowAdvances() throws {
        buildListWithTwoCues()
        element("cueFollow.1").click()
        let auto = app.menuItems["Auto-follow"]
        XCTAssertTrue(auto.waitForExistence(timeout: 5))
        auto.click()
        closeEditor()

        openTab("Playback")
        let go = element("cueGo")
        XCTAssertTrue(go.waitForExistence(timeout: 5))
        go.click()
        let current = element("cueCurrentNumber")
        // Fade 1 s + 0 s delay: cue 2 follows by itself.
        XCTAssertTrue(waitForValue("2", of: current, timeout: 8))
    }
}
