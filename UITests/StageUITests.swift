import XCTest

final class StageUITests: DMXUITestCase {
    func testDragFixtureUpdatesPosition() throws {
        addRGBFixtures(count: 1)
        openTab("Stage")
        let fixture = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'stageFixture.'")).firstMatch
        XCTAssertTrue(fixture.waitForExistence(timeout: 10))
        let before = (fixture.value as? String) ?? ""
        let start = fixture.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.5, thenDragTo: start.withOffset(CGVector(dx: 100, dy: 0)))
        let moved = NSPredicate(format: "value != %@", before)
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: moved, object: fixture)], timeout: 5), .completed)
        func x(_ s: String) -> Double? {
            s.split(separator: " ").first(where: { $0.hasPrefix("x=") }).flatMap { Double($0.dropFirst(2)) }
        }
        let after = (fixture.value as? String) ?? ""
        XCTAssertNotNil(x(before)); XCTAssertNotNil(x(after))
        XCTAssertGreaterThan(x(after) ?? 0, x(before) ?? 1, "x should increase after dragging right")
    }
}
