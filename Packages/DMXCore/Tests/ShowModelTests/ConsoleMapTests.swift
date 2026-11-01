import Testing
import Foundation
@testable import ShowModel

@Test func noteNumbers() throws {
    #expect(try ConsoleTarget.scene(bank: 1, scene: 1).noteNumber() == 0)
    #expect(try ConsoleTarget.scene(bank: 1, scene: 8).noteNumber() == 7)
    #expect(try ConsoleTarget.scene(bank: 2, scene: 1).noteNumber() == 8)
    #expect(try ConsoleTarget.scene(bank: 15, scene: 8).noteNumber() == 119)
    #expect(try ConsoleTarget.chase(1).noteNumber() == 120)
    #expect(try ConsoleTarget.chase(6).noteNumber() == 125)
    #expect(try ConsoleTarget.blackout.noteNumber() == 126)
}

@Test func unreachableRejected() {
    #expect(throws: ConsoleError.bankNotReachable(16)) { try ConsoleTarget.scene(bank: 16, scene: 1).noteNumber() }
    #expect(throws: ConsoleError.sceneOutOfRange(9)) { try ConsoleTarget.scene(bank: 1, scene: 9).noteNumber() }
    #expect(throws: ConsoleError.chaseOutOfRange(7)) { try ConsoleTarget.chase(7).noteNumber() }
    #expect(throws: ConsoleError.bankNotReachable(0)) { try ConsoleTarget.scene(bank: 0, scene: 1).noteNumber() }
}

@Test func allReachableCount() throws {
    let all = ConsoleTarget.allReachable
    #expect(all.count == 127)
    #expect(try all.map { try $0.noteNumber() } == (0...126).map { UInt8($0) })
    #expect(all.sorted() == all)
}

@Test func midiChannelValidated() {
    #expect(ConsoleMap(midiChannel: 17).validate().contains(.midiChannelOutOfRange(17)))
    #expect(ConsoleMap().validate().isEmpty)
}

@Test func consoleMapCodableRoundTrip() throws {
    var map = ConsoleMap(midiChannel: 4, noteOffDelayMs: nil)
    map.cells[.scene(bank: 1, scene: 2)] = ConsoleCell(name: "Warm", colorHex: "#FFAA00", notes: "n")
    map.cells[.chase(3)] = ConsoleCell(name: "Chase")
    map.looks = [ConsoleLook(name: "Look", targets: [.scene(bank: 1, scene: 2), .chase(3)])]
    let data = try JSONEncoder().encode(map)
    #expect(try JSONDecoder().decode(ConsoleMap.self, from: data) == map)
}
