import Testing
import Foundation
@testable import ShowModel

private func makeType(_ n: Int, name: String = "T") -> FixtureType {
    FixtureType(name: name, channels: (0..<n).map { ChannelDef(name: "c\($0)", function: .generic) })
}

@Test func addFixturesAutoAddresses() throws {
    let t = makeType(3, name: "RGB")
    var patch = Patch(types: [t])
    let added = try patch.addFixtures(typeID: t.id, count: 4, startAddress: nil, namePrefix: "Par")
    #expect(added.map(\.address) == [1, 4, 7, 10])
    #expect(added.map(\.name) == ["Par 1", "Par 2", "Par 3", "Par 4"])
    #expect(patch.fixtures.count == 4)
}

@Test func overlapDetected() {
    let t = makeType(3)
    let a = Fixture(name: "a", typeID: t.id, address: 1)
    let b = Fixture(name: "b", typeID: t.id, address: 3)
    #expect(Patch(types: [t], fixtures: [a, b]).validate() == [.overlap(a.id, b.id)])
}

@Test func pastEndDetected() {
    let t = makeType(16)
    let f = Fixture(name: "f", typeID: t.id, address: 500)
    #expect(Patch(types: [t], fixtures: [f]).validate() == [.pastEnd(f.id)])
}

@Test func growingTypeRevalidates() {
    var t = makeType(3)
    let a = Fixture(name: "a", typeID: t.id, address: 1)
    let b = Fixture(name: "b", typeID: t.id, address: 4)
    var patch = Patch(types: [t], fixtures: [a, b])
    #expect(patch.validate().isEmpty)
    t.channels.append(ChannelDef(name: "extra", function: .generic))
    patch.types = [t]
    #expect(patch.validate().contains(.overlap(a.id, b.id)))
}

@Test func duplicateScanner() {
    let t = makeType(1)
    let a = Fixture(name: "a", typeID: t.id, address: 1, consoleScanner: 3)
    let b = Fixture(name: "b", typeID: t.id, address: 2, consoleScanner: 3)
    #expect(Patch(types: [t], fixtures: [a, b]).validate() == [.duplicateScanner(3)])
    let c = Fixture(name: "c", typeID: t.id, address: 1, consoleScanner: 13)
    #expect(Patch(types: [t], fixtures: [c]).validate() == [.scannerOutOfRange(c.id)])
}

@Test func noRoomThrows() {
    let t = makeType(512)
    var patch = Patch(types: [t])
    #expect(throws: PatchError.noRoom) {
        try patch.addFixtures(typeID: t.id, count: 2, startAddress: nil, namePrefix: "X")
    }
    #expect(patch.fixtures.isEmpty)
}

@Test func codableRoundTrip() throws {
    let t = makeType(3)
    let patch = Patch(types: [t], fixtures: [Fixture(name: "a", typeID: t.id, address: 1, consoleScanner: 2, stagePosition: StagePoint(x: 0.5, y: 0.25))])
    let data = try JSONEncoder().encode(patch)
    #expect(try JSONDecoder().decode(Patch.self, from: data) == patch)
}
