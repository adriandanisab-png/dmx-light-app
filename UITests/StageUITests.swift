import XCTest

/// Synthetic XCUITest drags don't reach SwiftUI drag gestures reliably on macOS CI (recorded: the
/// fixture is selected but never moves), so dragging is checked by hand. See docs/decisions.md.
final class StageUITests: DMXUITestCase {
    func testNewFixtureIsInsideStageAndSelectable() throws {
        addRGBFixtures(count: 1)
        openTab("Stage")
        let fixture = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'stageFixture.'")).firstMatch
        XCTAssertTrue(fixture.waitForExistence(timeout: 10))
        // On screen and clear of the stage's bottom edge (it used to sit half cut off there).
        XCTAssertTrue(fixture.isHittable)
        let window = app.windows.firstMatch.frame
        XCTAssertLessThan(fixture.frame.maxY, window.maxY - 40, "fixture \(fixture.frame) window \(window)")
        fixture.click()
        XCTAssertTrue(fixture.isSelected)
    }
}
