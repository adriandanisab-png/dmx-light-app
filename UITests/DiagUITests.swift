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
final class DiagNone: DiagBase { func testD() { run1() } }
final class DiagNoEffects: DiagBase { override var extraLaunchArguments: [String] { ["-diagNoEffects"] }; func testD() { run1() } }
final class DiagNoCue: DiagBase { override var extraLaunchArguments: [String] { ["-diagNoCue"] }; func testD() { run1() } }
final class DiagNoScroll: DiagBase { override var extraLaunchArguments: [String] { ["-diagNoScroll"] }; func testD() { run1() } }
final class DiagNoBoth: DiagBase { override var extraLaunchArguments: [String] { ["-diagNoCue", "-diagNoEffects"] }; func testD() { run1() } }
final class DiagAllOff: DiagBase { override var extraLaunchArguments: [String] { ["-diagNoCue", "-diagNoEffects", "-diagNoScroll"] }; func testD() { run1() } }
