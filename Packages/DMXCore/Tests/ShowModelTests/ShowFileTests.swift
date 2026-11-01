import Testing
import Foundation
@testable import ShowModel

@Test func roundTrip() throws {
    var show = Show()
    let t = BuiltInTemplates.all[1]
    show.patch.types = [t]
    show.patch.fixtures = [Fixture(name: "Par 1", typeID: t.id, address: 1)]
    show.console.cells[.scene(bank: 1, scene: 1)] = ConsoleCell(name: "Warm")
    #expect(try Show.decode(show.encode()) == show)
}

@Test func garbageIsCorrupt() {
    #expect(throws: ShowFileError.corrupt) { try Show.decode(Data("x".utf8)) }
}

@Test func newerVersionRejected() throws {
    var show = Show()
    show.formatVersion = 2
    #expect(throws: ShowFileError.newerVersion(2)) { try Show.decode(show.encode()) }
    #expect(throws: ShowFileError.newerVersion(9)) { try Show.decode(Data(#"{"formatVersion":9,"weird":true}"#.utf8)) }
}
