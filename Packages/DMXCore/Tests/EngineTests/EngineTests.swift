import Testing
import Foundation
import ShowModel
import DMXOutput
@testable import Engine

struct Rig {
    let rgb = BuiltInTemplates.all.first { $0.name == "RGB" }!
    let dim = BuiltInTemplates.all.first { $0.name == "RGB + Dimmer + Strobe" }!
    let par1: Fixture, par2: Fixture, head: Fixture
    let patch: Patch
    init() {
        par1 = Fixture(name: "p1", typeID: rgb.id, address: 1)
        par2 = Fixture(name: "p2", typeID: rgb.id, address: 4)
        head = Fixture(name: "d", typeID: dim.id, address: 7)
        patch = Patch(types: [rgb, dim], fixtures: [par1, par2, head])
    }
    func input(_ snaps: [Snapshot] = [], playbacks: [PlaybackState] = []) -> EngineInput {
        EngineInput(patch: patch, snapshots: Dictionary(uniqueKeysWithValues: snaps.map { ($0.id, $0) }),
                    playbacks: playbacks)
    }
    func playback(_ s: Snapshot, start: TimeInterval = 0, fade: Double = 0, from: DMXFrame = DMXFrame()) -> PlaybackState {
        PlaybackState(snapshotID: s.id, startedAt: start, fade: fade, fadeFrom: from)
    }
}

private func snap(_ values: [UUID: FixtureValues]) -> Snapshot { Snapshot(name: "s", colorHex: "#FFFFFF", values: values) }

@Test func defaultsOnly() {
    let r = Rig()
    #expect(Engine.render(r.input(), at: 0) == PatchWriter.defaults(for: r.patch))
}

@Test func snapshotFullAfterFade() {
    let r = Rig()
    let s = snap([r.par1.id: [0: 255]])
    let pb = r.playback(s, start: 10, fade: 2)
    #expect(Engine.render(r.input([s], playbacks: [pb]), at: 12)[1] == 255)
    #expect(Engine.render(r.input([s], playbacks: [pb]), at: 11)[1] == 128)
    #expect(Engine.render(r.input([s], playbacks: [pb]), at: 5)[1] == 0)
    #expect(Engine.render(r.input([s], playbacks: [pb]), at: 99)[1] == 255)
}

@Test func zeroFadeIsInstant() {
    let r = Rig()
    let s = snap([r.par1.id: [0: 255]])
    #expect(Engine.render(r.input([s], playbacks: [r.playback(s, start: 3, fade: 0)]), at: 3)[1] == 255)
}

@Test func htpIntensityTwoPlaybacks() {
    let r = Rig()
    let a = snap([r.head.id: [0: 100]]), b = snap([r.head.id: [0: 200]]), c = snap([r.head.id: [0: 50]])
    #expect(Engine.render(r.input([a, b], playbacks: [r.playback(a), r.playback(b)]), at: 1)[7] == 200)
    #expect(Engine.render(r.input([a, c], playbacks: [r.playback(a), r.playback(c)]), at: 1)[7] == 100)
}

@Test func ltpColourLatestWins() {
    let r = Rig()
    let a = snap([r.par1.id: [0: 255], r.head.id: [1: 255]]), b = snap([r.par1.id: [0: 10], r.head.id: [1: 10]])
    let f = Engine.render(r.input([a, b], playbacks: [r.playback(a), r.playback(b)]), at: 1)
    #expect(f[1] == 10)
    #expect(f[8] == 10)
}

@Test func programmerOverrides() {
    let r = Rig()
    let s = snap([r.head.id: [0: 200]])
    var input = r.input([s], playbacks: [r.playback(s)])
    var prog = Programmer()
    prog.set(channel: 0, to: 20, for: [r.head.id])
    input.programmer = prog
    #expect(Engine.render(input, at: 1)[7] == 20)
}

@Test func grandMasterRGBOnly() {
    let r = Rig()
    let s = snap([r.par1.id: [0: 200], r.head.id: [0: 200, 1: 200]])
    var input = r.input([s], playbacks: [r.playback(s)])
    input.grandMaster = 0.5
    let f = Engine.render(input, at: 1)
    #expect(f[1] == 100)
    #expect(f[7] == 100)   // dimmer scaled
    #expect(f[8] == 200)   // its colour untouched
    input.grandMaster = 0
    #expect(Engine.render(input, at: 1)[1] == 0)
    input.grandMaster = 1
    input.blackout = true
    let b = Engine.render(input, at: 1)
    #expect(b[1] == 0)
    #expect(b[7] == 0)
    #expect(b[8] == 200)
}

@Test func deletedFixtureIgnored() {
    let r = Rig()
    let s = snap([UUID(): [0: 255], r.par2.id: [1: 99]])
    let f = Engine.render(r.input([s], playbacks: [r.playback(s)]), at: 1)
    #expect(f[5] == 99)
    var input = r.input([s], playbacks: [r.playback(s)])
    var prog = Programmer()
    prog.set(channel: 0, to: 1, for: [UUID()])
    input.programmer = prog
    _ = Engine.render(input, at: 1)
}

@Test func unknownSnapshotAndBadChannelIgnored() {
    let r = Rig()
    let s = snap([r.par1.id: [9: 255, -1: 5]])
    var input = r.input([s], playbacks: [r.playback(s), PlaybackState(snapshotID: UUID(), startedAt: 0, fade: 0, fadeFrom: DMXFrame())])
    input.snapshots = [s.id: s]
    #expect(Engine.render(input, at: 1) == PatchWriter.defaults(for: r.patch))
}

@Test func interruptedFadeNoJump() {
    let r = Rig()
    let a = snap([r.par1.id: [0: 255]])
    let at = Engine.render(r.input([a], playbacks: [r.playback(a, start: 0, fade: 2)]), at: 1)   // mid fade: 128
    #expect(at[1] == 128)
    let b = snap([r.par1.id: [0: 0]])
    let pb = r.playback(b, start: 1, fade: 2, from: at)
    let first = Engine.render(r.input([b], playbacks: [pb]), at: 1)
    #expect(first[1] == at[1])
    #expect(Engine.render(r.input([b], playbacks: [pb]), at: 3)[1] == 0)
}

@Test func isIntensityClassification() {
    #expect(Engine.isIntensity(.intensity, typeHasIntensity: true))
    #expect(!Engine.isIntensity(.red, typeHasIntensity: true))
    #expect(Engine.isIntensity(.red, typeHasIntensity: false))
    #expect(Engine.isIntensity(.uv, typeHasIntensity: false))
    #expect(!Engine.isIntensity(.strobe, typeHasIntensity: false))
}

/// Recalling look B over look A: channels only A used fade back to their defaults over B's fade, no jump.
@Test func releasedChannelsFadeOut() {
    let r = Rig()
    let a = snap([r.par1.id: [0: 255]])
    let b = snap([r.par2.id: [0: 255]])
    var from = DMXFrame(); from[1] = 255          // A fully on when B is recalled
    let pb = r.playback(b, start: 10, fade: 2, from: from)
    let input = r.input([a, b], playbacks: [pb])
    #expect(Engine.render(input, at: 10)[1] == 255)
    #expect(Engine.render(input, at: 11)[1] == 128)
    #expect(Engine.render(input, at: 12)[1] == 0)
    #expect(Engine.render(input, at: 11)[4] == 128)
}
