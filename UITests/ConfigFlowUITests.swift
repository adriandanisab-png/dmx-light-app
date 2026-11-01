import XCTest

final class ConfigFlowUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        // If the app shows an Open panel instead of an untitled document, create one.
        // Dismiss the launch Open panel if present, then make a new untitled document.
        if app.buttons["New Document"].firstMatch.waitForExistence(timeout: 3) {
            app.typeKey(.escape, modifierFlags: [])
        }
        app.typeKey("n", modifierFlags: .command)
        _ = app.windows.firstMatch.waitForExistence(timeout: 5)
        print("UI DIAG windows=\(app.windows.count) sheets=\(app.sheets.count) dialogs=\(app.dialogs.count) buttons=\(app.buttons.count) all=\(app.descendants(matching: .any).count)")
        for b in app.buttons.allElementsBoundByIndex.prefix(30) { print("UI DIAG button id=\(b.identifier) label=\(b.label)") }
        for w in app.windows.allElementsBoundByIndex { print("UI DIAG window id=\(w.identifier) title=\(w.title)") }
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// New document, Config tab, New from template... -> RGB, Add fixtures (count 4):
    /// the patch table shows 4 rows at addresses 1, 4, 7, 10.
    func testAddRGBFixturesShowsFourRows() throws {
        // Config is the first tab and is selected by default.
        let templates = element("newFromTemplate")
        XCTAssertTrue(templates.waitForExistence(timeout: 10))
        templates.click()
        let rgb = app.menuItems["RGB"]
        XCTAssertTrue(rgb.waitForExistence(timeout: 5))
        rgb.click()

        let add = element("addFixturesButton")
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.click()

        let count = element("addCount")
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        count.click()
        count.typeKey("a", modifierFlags: .command)
        count.typeText("4")
        element("addFixturesConfirm").click()

        for address in [1, 4, 7, 10] {
            XCTAssertTrue(element("patchRow.\(address)").waitForExistence(timeout: 5),
                          "expected a patch row at address \(address)")
        }
        XCTAssertFalse(element("patchRow.13").exists)
        XCTAssertFalse(element("patchIssueBanner").exists)
    }
}
