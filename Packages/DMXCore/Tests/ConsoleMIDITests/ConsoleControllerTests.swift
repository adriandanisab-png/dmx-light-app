import Testing
import Foundation
import ShowModel
@testable import ConsoleMIDI

@MainActor
private func make(channel: Int = 1, noteOff: Int? = 0, armed: Bool = true) -> (ConsoleController, RecordingMIDISender) {
    let s = RecordingMIDISender()
    let c = ConsoleController(sender: s, map: ConsoleMap(midiChannel: channel, noteOffDelayMs: noteOff))
    c.isArmed = armed
    return (c, s)
}

@MainActor
@Test func fireSendsNoteOnThenOff() async throws {
    let (c, s) = make(channel: 3)
    try await c.fire(.scene(bank: 2, scene: 1))
    #expect(s.sent.map(\.bytes) == [[0x92, 8, 127], [0x82, 8, 0]])
    #expect(c.state.on.contains(.scene(bank: 2, scene: 1)))
}

@MainActor
@Test func noNoteOffWhenDisabled() async throws {
    let (c, s) = make(noteOff: nil)
    try await c.fire(.chase(1))
    #expect(s.sent.map(\.bytes) == [[0x90, 120, 127]])
}

@MainActor
@Test func noteOffWaitsForDelay() async throws {
    let (c, _) = make(noteOff: 50)
    let t0 = ContinuousClock.now
    try await c.fire(.chase(1))
    #expect(ContinuousClock.now - t0 >= .milliseconds(40))
}

@MainActor
@Test func notArmedSendsNothing() async {
    let (c, s) = make(armed: false)
    await #expect(throws: ConsoleError.notArmed) { try await c.fire(.scene(bank: 1, scene: 1)) }
    #expect(s.sent.isEmpty)
    #expect(c.state == ConsoleState())
}

@MainActor
@Test func sendFailureKeepsState() async {
    let (c, s) = make()
    s.failNextSend = true
    await #expect(throws: ConsoleError.sendFailed("simulated failure")) { try await c.fire(.scene(bank: 1, scene: 1)) }
    #expect(c.state == ConsoleState())
    #expect(s.sent.isEmpty)
}

@MainActor
@Test func disconnectedKeepsState() async {
    let (c, s) = make()
    s.isConnected = false
    await #expect(throws: ConsoleError.noDestination) { try await c.fire(.blackout) }
    #expect(c.state == ConsoleState())
}

@MainActor
@Test func recallSendsOnlyDiff() async throws {
    let (c, s) = make(noteOff: nil)
    try await c.fire(.scene(bank: 1, scene: 1))
    let before = s.sent.count
    try await c.recall(ConsoleLook(name: "L", targets: [.scene(bank: 1, scene: 2)]))
    #expect(s.sent.dropFirst(before).map(\.bytes) == [[0x90, 0, 127], [0x90, 1, 127]])
    #expect(c.state.on == [.scene(bank: 1, scene: 2)])
}

@MainActor
@Test func unreachableNeverSends() async {
    let (c, s) = make()
    await #expect(throws: ConsoleError.bankNotReachable(20)) { try await c.fire(.scene(bank: 20, scene: 1)) }
    #expect(s.sent.isEmpty)
}
