import XCTest

final class ProgrammerUITests: DMXUITestCase {
    func testRecordSnapshot() throws {
        addRGBFixtures(count: 2)
        recordRedSnapshot(named: "Red wash")
        XCTAssertTrue(element("librarySnapshot.0").waitForExistence(timeout: 5))
        // macOS exposes a Text's string as its value, not its label.
        let row = element("librarySnapshot.0")
        XCTAssertEqual((row.value as? String) ?? row.label, "Red wash")
        XCTAssertFalse(element("librarySnapshot.1").exists, "the library should hold exactly one snapshot")
    }
}
