import Testing
import Foundation
@testable import Effects

@Test func fourTapsAt0_5s() {
    var t = TapTempo()
    for i in 0..<4 { t.tap(at: Double(i) * 0.5) }
    #expect(abs(t.bpm - 120) < 1e-9)
}

@Test func singleTapNoChange() {
    var t = TapTempo()
    t.set(bpm: 90)
    t.tap(at: 5)
    #expect(t.bpm == 90)
}

@Test func gapResets() {
    var t = TapTempo()
    t.tap(at: 0); t.tap(at: 0.5)
    #expect(abs(t.bpm - 120) < 1e-9)
    t.tap(at: 10)
    #expect(abs(t.bpm - 120) < 1e-9)
    t.tap(at: 10.25)
    #expect(abs(t.bpm - 240) < 1e-9)
}

@Test func clampHigh() {
    var t = TapTempo()
    t.tap(at: 0); t.tap(at: 0.05); t.tap(at: 0.1)
    #expect(t.bpm == 300)
}

@Test func setClamps() {
    var t = TapTempo()
    t.set(bpm: 5); #expect(t.bpm == 20)
    t.set(bpm: 999); #expect(t.bpm == 300)
}
