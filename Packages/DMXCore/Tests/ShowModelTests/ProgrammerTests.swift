import Testing
import Foundation
@testable import ShowModel

private func rig() -> (Patch, Fixture, Fixture) {
    let rgb = TestTypes.rgb, rgbw = TestTypes.rgbw
    let a = Fixture(name: "a", typeID: rgb.id, address: 1)
    let b = Fixture(name: "b", typeID: rgbw.id, address: 4)
    return (Patch(types: [rgb, rgbw], fixtures: [a, b]), a, b)
}

@Test func onlyTouchedChannelsRecorded() {
    let (patch, a, b) = rig()
    var p = Programmer()
    p.selection = [a.id, b.id]
    p.apply({ t, v in Attributes.setColor(RGB(r: 1, g: 0, b: 0), type: t, into: &v) }, patch: patch)
    let snap = p.record(name: "Red", colorHex: "#FF0000")
    #expect(snap.name == "Red")
    #expect(Set(snap.values.keys) == [a.id, b.id])
    #expect(Set(snap.values[a.id]!.keys) == [0, 1, 2])
    #expect(Set(snap.values[b.id]!.keys) == [0, 1, 2, 3])
}

@Test func setChannelTouchesOnlyThatChannel() {
    let (_, a, b) = rig()
    var p = Programmer()
    p.set(channel: 1, to: 77, for: [a.id, b.id])
    #expect(p.values[a.id] == [1: 77])
    #expect(p.values[b.id] == [1: 77])
}

@Test func clearEmpties() {
    let (patch, a, _) = rig()
    var p = Programmer()
    p.selection = [a.id]
    p.apply({ t, v in Attributes.setColor(RGB(r: 1, g: 1, b: 1), type: t, into: &v) }, patch: patch)
    #expect(!p.values.isEmpty)
    p.clear()
    #expect(p.values.isEmpty)
    #expect(p.selection.isEmpty)
    #expect(p.record(name: "x", colorHex: "#000000").values.isEmpty)
}

@Test func applyUsesEachFixturesType() {
    let (patch, a, b) = rig()
    var p = Programmer()
    p.selection = [a.id, b.id]
    p.apply({ t, v in Attributes.setColor(RGB(r: 1, g: 1, b: 1), type: t, into: &v) }, patch: patch)
    #expect(p.values[a.id] == [0: 255, 1: 255, 2: 255])
    #expect(p.values[b.id]?[3] == 255)
    #expect(p.values[b.id]?[0] == 0)
}

@Test func applyIgnoresUnknownFixtures() {
    let (patch, _, _) = rig()
    var p = Programmer()
    p.selection = [UUID()]
    p.apply({ _, v in v[0] = 1 }, patch: patch)
    #expect(p.values.isEmpty)
}
