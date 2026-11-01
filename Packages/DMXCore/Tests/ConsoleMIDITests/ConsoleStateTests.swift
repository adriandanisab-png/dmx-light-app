import Testing
import ShowModel
@testable import ConsoleMIDI

@Test func diffTurnsOffAndOn() {
    var s = ConsoleState()
    s.applyToggle(.scene(bank: 1, scene: 1))
    s.applyToggle(.scene(bank: 1, scene: 2))
    let t: Set<ConsoleTarget> = [.scene(bank: 1, scene: 2), .chase(1)]
    #expect(s.toggles(toReach: t) == [.scene(bank: 1, scene: 1), .chase(1)])
}

@Test func sameLookNoToggles() {
    var s = ConsoleState()
    s.applyToggle(.chase(2))
    #expect(s.toggles(toReach: [.chase(2)]).isEmpty)
}

@Test func blackoutFlips() {
    var s = ConsoleState()
    s.applyToggle(.blackout)
    #expect(s.blackout)
    s.applyToggle(.blackout)
    #expect(!s.blackout)
}

@Test func resetClears() {
    var s = ConsoleState()
    s.applyToggle(.chase(1)); s.applyToggle(.blackout)
    s.reset()
    #expect(s == ConsoleState())
}
