import Testing
import Foundation
import ShowModel
@testable import Engine

private struct Fix {
    var show = Show()
    let snap = Snapshot(name: "s", colorHex: "#FFFFFF")
    let look = ConsoleLook(name: "l", targets: [.scene(bank: 1, scene: 1)])
    init() { show.snapshots = [snap]; show.console.looks = [look] }
    func direct() -> DirectCuePart { DirectCuePart(snapshotIDs: [snap.id]) }
    func console() -> ConsoleCuePart { .look(look.id) }
    func cue(_ n: Double, direct: Bool = true, console: Bool = true, fade: Double = 1,
             follow: CueFollow = .manual) -> Cue {
        Cue(number: n, name: "c\(n)", fade: fade, follow: follow,
            direct: direct ? self.direct() : nil, console: console ? self.console() : nil)
    }
    func player(_ cues: [Cue], loops: Bool = false) -> CueListPlayer {
        CueListPlayer(list: CueList(name: "L", cues: cues, loops: loops), show: show)
    }
}

private func number(_ a: CueAction) -> Double? {
    switch a {
    case let .playDirect(c), let .playConsole(c), let .skipped(c, _): return c.number
    case .end: return nil
    }
}

@Test func goPlaysInOrder() {
    let f = Fix()
    var p = f.player([f.cue(1), f.cue(2), f.cue(3)])
    #expect(p.go(mode: .direct).map(number) == [1])
    #expect(p.go(mode: .direct).map(number) == [2])
    if case .playDirect = p.go(mode: .direct).last! {} else { Issue.record("not direct") }
}

@Test func skipsCueWithoutModePart() {
    let f = Fix()
    var p = f.player([f.cue(1), f.cue(2, console: false), f.cue(3)])
    let first = p.go(mode: .console)
    #expect(first.count == 1)
    if case .playConsole = first[0] {} else { Issue.record("not console") }
    let second = p.go(mode: .console)
    #expect(second.count == 2)
    if case .skipped(let c, _) = second[0] { #expect(c.number == 2) } else { Issue.record("not skipped") }
    if case .playConsole(let c) = second[1] { #expect(c.number == 3) } else { Issue.record("not played") }
}

@Test func modeSwitchKeepsIndex() {
    let f = Fix()
    var p = f.player([f.cue(1), f.cue(2), f.cue(3)])
    _ = p.go(mode: .direct); _ = p.go(mode: .direct)
    #expect(p.currentIndex == 1)
    let a = p.go(mode: .console)
    if case .playConsole(let c) = a.last! { #expect(c.number == 3) } else { Issue.record("expected console cue 3") }
}

@Test func allMissingEndsNoHang() {
    let f = Fix()
    var p = f.player([f.cue(1, console: false), f.cue(2, console: false), f.cue(3, console: false)], loops: true)
    let a = p.go(mode: .console)
    #expect(a.count == 4)
    #expect(a.dropLast().allSatisfy { if case .skipped = $0 { true } else { false } })
    #expect(a.last == .end)
}

@Test func deletedSnapshotMakesCueMissing() {
    var f = Fix()
    let gone = Cue(number: 2, direct: DirectCuePart(snapshotIDs: [UUID()]))
    let p0 = f.player([f.cue(1), gone, f.cue(3)])
    var p = p0
    _ = p.go(mode: .direct)
    let a = p.go(mode: .direct)
    if case .skipped(let c, _) = a[0] { #expect(c.number == 2) } else { Issue.record("not skipped") }
    // Partially missing still plays.
    f.show.snapshots = [f.snap]
    var q = f.player([Cue(number: 1, direct: DirectCuePart(snapshotIDs: [UUID(), f.snap.id]))])
    if case .playDirect = q.go(mode: .direct)[0] {} else { Issue.record("should play") }
    // Missing console look.
    var r = f.player([Cue(number: 1, console: .look(UUID()))])
    if case .skipped = r.go(mode: .console)[0] {} else { Issue.record("look should be missing") }
}

@Test func endWithoutLoop() {
    let f = Fix()
    var p = f.player([f.cue(1)])
    _ = p.go(mode: .direct)
    #expect(p.go(mode: .direct) == [.end])
    #expect(p.currentIndex == 0)
}

@Test func loopWraps() {
    let f = Fix()
    var p = f.player([f.cue(1), f.cue(2)], loops: true)
    _ = p.go(mode: .direct); _ = p.go(mode: .direct)
    #expect(p.go(mode: .direct).map(number) == [1])
}

@Test func backAndJump() {
    let f = Fix()
    var p = f.player([f.cue(1), f.cue(2), f.cue(3)])
    #expect(p.jump(to: 3, mode: .direct).map(number) == [3])
    #expect(p.back(mode: .direct).map(number) == [2])
    #expect(p.jump(to: 9, mode: .direct) == [])
    #expect(p.currentIndex == 1)
}

@Test func autoFollow() {
    let f = Fix()
    var p = f.player([f.cue(1, fade: 1, follow: .auto(after: 2))])
    #expect(!p.nextAutoFollow(at: 100, cueStartedAt: 0)) // not started
    _ = p.go(mode: .direct)
    #expect(p.nextAutoFollow(at: 3.0, cueStartedAt: 0))
    #expect(!p.nextAutoFollow(at: 2.9, cueStartedAt: 0))
    let m = f.player([f.cue(1)])
    var mm = m
    _ = mm.go(mode: .direct)
    #expect(!mm.nextAutoFollow(at: 100, cueStartedAt: 0))
}

@Test func cuesSortedByNumber() {
    let f = Fix()
    var p = f.player([f.cue(2), f.cue(1), f.cue(1.5)].shuffled())
    #expect(p.go(mode: .direct).map(number) == [1])
    #expect(p.go(mode: .direct).map(number) == [1.5])
    #expect(p.go(mode: .direct).map(number) == [2])
}
