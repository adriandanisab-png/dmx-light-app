import XCTest

/// Captures a full-window screenshot of every page for design review. CI exports the attachments.
final class ScreenshotUITests: DMXUITestCase {
    override var extraLaunchArguments: [String] { ["-useRecordingMIDI"] }

    private func capture(_ page: String, tab: String) {
        openTab(tab)
        Thread.sleep(forTimeInterval: 1.0)  // let fades / animations settle
        let shot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = page
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCaptureAllPages() throws {
        addRGBFixtures(count: 4)
        recordRedSnapshot(named: "Red wash")
        // Start a preset chase on all fixtures so Playback and Stage show something running.
        element("clearProgrammer").click()
        openTab("Playback")
        let chase = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'effectPreset.'")).firstMatch
        XCTAssertTrue(chase.waitForExistence(timeout: 10))
        chase.click()
        let red = element("playbackButton.Red wash")
        if red.waitForExistence(timeout: 5) { red.click() }
        // Pull the snapshot fader up so the Faders card shows a lit strip.
        let fader = element("snapshotFader.Red wash")
        if fader.waitForExistence(timeout: 5) { fader.adjust(toNormalizedSliderPosition: 0.7) }

        // The effect clicks scrolled the page down; bring the Faders card back to the top for the shot.
        for sv in app.scrollViews.allElementsBoundByIndex where sv.frame.width > 300 {
            sv.scroll(byDeltaX: 0, deltaY: 3000)
        }
        capture("1-Playback", tab: "Playback")
        // Re-select a fixture and set a colour so the Programmer page is populated.
        openTab("Programmer")
        let all = element("selectAllButton")
        if all.waitForExistence(timeout: 5) { all.click() }
        element("swatch.blue").click()
        capture("2-Programmer", tab: "Programmer")
        capture("3-Stage", tab: "Stage")
        capture("4-Library", tab: "Library")
        capture("5-Fixtures", tab: "Config")
        capture("6-Devices", tab: "Devices")
        capture("7-Console", tab: "Console")
    }
}
