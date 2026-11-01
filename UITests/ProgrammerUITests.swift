import XCTest

final class ProgrammerUITests: DMXUITestCase {
    func testRecordSnapshot() throws {
        addRGBFixtures(count: 2)
        recordRedSnapshot(named: "Red wash")
        XCTAssertTrue(element("librarySnapshot.0").waitForExistence(timeout: 5))
        XCTAssertEqual(element("librarySnapshot.0").label, "Red wash")
        XCTAssertFalse(element("librarySnapshot.1").exists, "the library should hold exactly one snapshot")
    }
}
