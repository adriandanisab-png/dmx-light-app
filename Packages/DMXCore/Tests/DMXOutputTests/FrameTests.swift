import Testing
import ShowModel
@testable import DMXOutput

@Test func frameIsOneBased() {
    var f = DMXFrame()
    f[1] = 255
    #expect(f.bytes[0] == 255)
    f[513] = 9
    f[0] = 9
    #expect(f.bytes.count == 512)
    #expect(f.bytes.filter { $0 != 0 }.count == 1)
    #expect(f[0] == 0)
    #expect(f[513] == 0)
}

@Test func defaultsUseChannelDefaults() {
    let t = FixtureType(name: "T", channels: [
        ChannelDef(name: "a", function: .generic),
        ChannelDef(name: "b", function: .generic, defaultValue: 128),
    ])
    let patch = Patch(types: [t], fixtures: [Fixture(name: "f", typeID: t.id, address: 10)])
    let frame = PatchWriter.defaults(for: patch)
    #expect(frame[11] == 128)
    #expect(frame[10] == 0)
}

@Test func writerTargetsFixtureChannel() {
    let t = FixtureType(name: "T", channels: (0..<4).map { ChannelDef(name: "c\($0)", function: .generic) })
    let f = Fixture(name: "f", typeID: t.id, address: 20)
    let patch = Patch(types: [t], fixtures: [f])
    var frame = DMXFrame()
    PatchWriter.set(77, channel: 2, of: f, in: &frame, patch: patch)
    #expect(frame[22] == 77)
}
