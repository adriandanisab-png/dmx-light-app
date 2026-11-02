import Testing
import Foundation
import ShowModel
import DMXOutput
@testable import Engine

private func effectInput(_ r: Rig, _ e: Effect, level: Double = 1, start: TimeInterval = 0,
                         snaps: [Snapshot] = [], playbacks: [PlaybackState] = []) -> EngineInput {
    var i = r.input(snaps, playbacks: playbacks)
    i.effects = [e.id: e]
    i.runningEffects = [RunningEffect(effectID: e.id, startedAt: start, level: level)]
    i.bpm = 120
    return i
}

@Test func waveOnDimmers() {
    let r = Rig()
    // One dimmer-capable fixture and two dimmer-less pars; size 1, t=0.25 -> phase 0.5 -> wave peak.
    let e = Effect(kind: .intensityWave, fixtureIDs: [r.head.id], spread: 0)
    let f = Engine.render(effectInput(r, e), at: 0.25)
    #expect(f[7] == 255)
    #expect(Engine.render(effectInput(r, e), at: 0)[7] == 0)
    #expect(Engine.render(effectInput(r, e), at: 0.125)[7] == 127) // 0.5 - 0.5cos(pi/2) = 0.5
}

@Test func waveScalesColourWhenNoDimmer() {
    let r = Rig()
    let s = Snapshot(name: "s", colorHex: "#FFFFFF", values: [r.par1.id: [0: 200, 1: 100, 2: 0]])
    let pb = r.playback(s)
    let e = Effect(kind: .intensityWave, fixtureIDs: [r.par1.id], spread: 0, direction: .forward)
    let f = Engine.render(effectInput(r, e, snaps: [s], playbacks: [pb]), at: 0.125) // 0.5 of wave
    #expect(f[1] == 100 && f[2] == 50 && f[3] == 0)
}

@Test func rainbowOverSnapshot() {
    let r = Rig()
    let s = Snapshot(name: "s", colorHex: "#FFFFFF", values: [r.par1.id: [0: 0, 1: 0, 2: 255]])
    let pb = r.playback(s)
    let e = Effect(kind: .rainbow, fixtureIDs: [r.par1.id], spread: 0)
    let full = Engine.render(effectInput(r, e, level: 1, snaps: [s], playbacks: [pb]), at: 0) // red
    #expect(full[1] == 255 && full[2] == 0 && full[3] == 0)
    let half = Engine.render(effectInput(r, e, level: 0.5, snaps: [s], playbacks: [pb]), at: 0)
    #expect(half[1] == 128 && half[2] == 0 && half[3] == 128)
}

@Test func levelZeroIsNoop() {
    let r = Rig()
    let e = Effect(kind: .rainbow, fixtureIDs: [r.par1.id], spread: 0)
    #expect(Engine.render(effectInput(r, e, level: 0), at: 0) == Engine.render(r.input(), at: 0))
}

@Test func overlayStrobeBlendsByLevel() {
    let r = Rig()
    let s = Snapshot(name: "s", colorHex: "#FFFFFF", values: [r.head.id: [0: 200]])
    let e = Effect(kind: .strobe, fixtureIDs: [r.head.id])
    // t=0.3 -> base 0.6 -> off. level 0.5 halves the look.
    let f = Engine.render(effectInput(r, e, level: 0.5, snaps: [s], playbacks: [r.playback(s)]), at: 0.3)
    #expect(f[7] == 100)
}

@Test func panTiltOnParsIgnored() {
    let r = Rig()
    let s = Snapshot(name: "s", colorHex: "#FFFFFF", values: [r.par1.id: [0: 10, 1: 20, 2: 30]])
    let pb = r.playback(s)
    let base = Engine.render(r.input([s], playbacks: [pb]), at: 0)
    let e = Effect(kind: .panTiltCircle, fixtureIDs: [r.par1.id, r.par2.id])
    #expect(Engine.render(effectInput(r, e, snaps: [s], playbacks: [pb]), at: 0.1) == base)
}

@Test func panTiltMovesHead() {
    let mh = BuiltInTemplates.all.first { $0.name == "Moving Head 16ch" }!
    let fx = Fixture(name: "mh", typeID: mh.id, address: 1)
    let patch = Patch(types: [mh], fixtures: [fx])
    let e = Effect(kind: .panTiltCircle, fixtureIDs: [fx.id], spread: 0)
    var i = EngineInput(patch: patch)
    i.effects = [e.id: e]; i.runningEffects = [RunningEffect(effectID: e.id, startedAt: 0)]
    let panIdx = mh.channels.firstIndex { $0.function == .pan }!
    let panFine = mh.channels.firstIndex { $0.function == .panFine }!
    let base = Engine.render(EngineInput(patch: patch), at: 0)
    let f = Engine.render(i, at: 0) // pan offset +0.5 from default
    let basePan = Int(base[1 + panIdx]) << 8 | Int(base[1 + panFine])
    let pan = Int(f[1 + panIdx]) << 8 | Int(f[1 + panFine])
    #expect(basePan == 0 && abs(pan - 32768) <= 1)
}

@Test func programmerStillWins() {
    let r = Rig()
    let e = Effect(kind: .rainbow, fixtureIDs: [r.par1.id], spread: 0)
    var i = effectInput(r, e)
    var prog = Programmer()
    prog.set(channel: 0, to: 7, for: [r.par1.id])
    i.programmer = prog
    #expect(Engine.render(i, at: 0)[1] == 7)
}

@Test func blackoutStillWins() {
    let r = Rig()
    let e = Effect(kind: .intensityWave, fixtureIDs: [r.head.id], spread: 0)
    var i = effectInput(r, e)
    i.blackout = true
    #expect(Engine.render(i, at: 0.25)[7] == 0)
}

@Test func missingEffectIgnored() {
    let r = Rig()
    var i = r.input()
    i.runningEffects = [RunningEffect(effectID: UUID(), startedAt: 0)]
    #expect(Engine.render(i, at: 0) == Engine.render(r.input(), at: 0))
}
