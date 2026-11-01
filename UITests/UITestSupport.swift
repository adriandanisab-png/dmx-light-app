import XCTest

/// Shared helpers for the Plan 2 UI tests. These run on GitHub CI (no Xcode locally).
class DMXUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        // Dismiss the launch Open panel if present, then make a new untitled document.
        if app.buttons["New Document"].firstMatch.waitForExistence(timeout: 3) {
            app.typeKey(.escape, modifierFlags: [])
        }
        app.typeKey("n", modifierFlags: .command)
        _ = app.windows.firstMatch.waitForExistence(timeout: 5)
    }

    func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func openTab(_ name: String) {
        let tab = app.radioButtons[name].exists ? app.radioButtons[name] : app.tabs[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "tab \(name)")
        tab.click()
    }

    func waitForValue(_ value: String, of el: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: el)], timeout: timeout) == .completed
    }

    /// Config tab: RGB template, then `count` fixtures.
    func addRGBFixtures(count: Int) {
        openTab("Config")
        let templates = element("newFromTemplate")
        XCTAssertTrue(templates.waitForExistence(timeout: 10))
        templates.click()
        let rgb = app.menuItems["RGB"]
        XCTAssertTrue(rgb.waitForExistence(timeout: 5))
        rgb.click()
        let add = element("addFixturesButton")
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.click()
        let field = element("addCount")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText("\(count)")
        element("addFixturesConfirm").click()
        XCTAssertTrue(element("patchRow.1").waitForExistence(timeout: 5))
    }

    /// Programmer tab: select all fixtures, pick red, record a snapshot.
    func recordRedSnapshot(named name: String) {
        openTab("Programmer")
        let all = element("selectAllButton")
        XCTAssertTrue(all.waitForExistence(timeout: 5))
        all.click()
        element("swatch.red").click()
        element("recordButton").click()
        let nameField = element("snapshotName")
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.click()
        nameField.typeText(name)
        element("snapshotSave").click()
    }
}
