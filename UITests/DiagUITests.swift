import XCTest

class DiagBase: DMXUITestCase {
    func run1() {
        addRGBFixtures(count: 2)
        openTab("Playback")
        let blackout = element("blackoutButton")
        XCTAssertTrue(blackout.waitForExistence(timeout: 5))
        app.typeKey("b", modifierFlags: [])
        Thread.sleep(forTimeInterval: 1)
        XCTFail("RESULT \(extraLaunchArguments): \(blackout.value as? String ?? "?")")
    }
}
final class DiagNoLib: DiagBase { override var extraLaunchArguments: [String] { ["-diagNoLibrary"] }; func testD() { run1() } }
final class DiagNoOC: DiagBase { override var extraLaunchArguments: [String] { ["-diagNoOnChange"] }; func testD() { run1() } }
final class DiagNoLibOC: DiagBase { override var extraLaunchArguments: [String] { ["-diagNoOnChange", "-diagNoLibrary"] }; func testD() { run1() } }
final class DiagAll: DiagBase { override var extraLaunchArguments: [String] { ["-diagNoCue", "-diagNoEffects", "-diagNoScroll", "-diagNoOnChange", "-diagNoLibrary"] }; func testD() { run1() } }
