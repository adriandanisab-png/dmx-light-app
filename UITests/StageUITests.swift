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
        func coord(_ key: String) -> Double? {
            ((fixture.value as? String) ?? "").split(separator: " ")
                .first(where: { $0.hasPrefix(key + "=") }).flatMap { Double($0.dropFirst(key.count + 1)) }
        }
        let x = try XCTUnwrap(coord("x")), y = try XCTUnwrap(coord("y"))
        XCTAssertTrue((0.05...0.95).contains(x), "x=\(x)")
        XCTAssertTrue((0.05...0.85).contains(y), "new fixtures sit inside the stage, not on its edge: y=\(y)")
        fixture.click()
        XCTAssertTrue(fixture.isSelected)
    }
}
