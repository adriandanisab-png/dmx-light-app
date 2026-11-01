import XCTest

final class ConsoleFlowUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Replace CoreMIDI with a connected RecordingMIDISender.
        app.launchArguments += ["-useRecordingMIDI"]
        app.launch()
        // If the app shows an Open panel instead of an untitled document, create one.
        // Dismiss the launch Open panel if present, then make a new untitled document.
        if app.buttons["New Document"].firstMatch.waitForExistence(timeout: 3) {
            app.typeKey(.escape, modifierFlags: [])
        }
        app.typeKey("n", modifierFlags: .command)
        _ = app.windows.firstMatch.waitForExistence(timeout: 5)
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func openConsoleTab() {
        let tab = app.radioButtons["Console"].exists ? app.radioButtons["Console"] : app.tabs["Console"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.click()
    }

    private func waitForValue(_ value: String, of el: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: el)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    func testFiringWithoutArmShowsToast() throws {
        openConsoleTab()
        // Playback mode is the default.
        let cell = element("consoleCell.b1s1")
        XCTAssertTrue(cell.waitForExistence(timeout: 10))
        cell.click()

        XCTAssertTrue(app.staticTexts["Output not armed"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForValue("off", of: cell), "cell must stay off when nothing was sent")

        // Arm, then fire again: the cell becomes lit.
        let arm = element("armButton")
        XCTAssertTrue(arm.exists)
        arm.click()
        XCTAssertTrue(waitForValue("on", of: arm))
        cell.click()
        XCTAssertTrue(waitForValue("on", of: cell), "cell should be believed on after a successful send")
    }
}
