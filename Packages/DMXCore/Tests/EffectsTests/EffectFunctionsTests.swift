import Testing
import Foundation
import ShowModel
@testable import Effects

private func fx(_ kind: EffectKind, count: Int = 4, size: Double = 1, spread: Double = 1,
                direction: EffectDirection = .forward, colors: [RGB] = []) -> Effect {
    Effect(kind: kind, fixtureIDs: (0..<count).map { _ in UUID() }, size: size, spread: spread,
           direction: direction, colors: colors)
}

@Test func chaseSteps() {
    let e = fx(.intensityChase)
    func on(_ i: Int, _ t: Double) -> Bool { EffectFunctions.output(effect: e, index: i, count: 4, time: t, bpm: 120).intensity == 1 }
    #expect(on(0, 0) && !on(1, 0) && !on(2, 0) && !on(3, 0))
    #expect(on(1, 0.125) && !on(0, 0.125))
}

@Test func waveHalfway() {
    let e = fx(.intensityWave, size: 0.8)
    let o = EffectFunctions.output(effect: e, index: 0, count: 4, time: 0.25, bpm: 120)
    #expect(abs(o.intensity! - 0.8) < 1e-9)
}

@Test func sparkleDeterministic() {
    let e = fx(.sparkle)
    let a = EffectFunctions.output(effect: e, index: 2, count: 4, time: 3.3, bpm: 120)
    #expect(a == EffectFunctions.output(effect: e, index: 2, count: 4, time: 3.3, bpm: 120))
    var on = 0
    for step in 0..<1000 where EffectFunctions.output(effect: e, index: 0, count: 4, time: Double(step) / 2 + 0.1, bpm: 120).intensity == 1 { on += 1 }
    let ratio = Double(on) / 1000
    #expect(ratio > 0.15 && ratio < 0.25)
}

@Test func rainbowHue() {
    let e = fx(.rainbow, spread: 0)
    let red = EffectFunctions.output(effect: e, index: 0, count: 4, time: 0, bpm: 120).color!
    #expect(abs(red.r - 1) < 0.01 && red.g < 0.01 && red.b < 0.01)
    // phase 1/3 at hz 2: t = 1/6
    let g = EffectFunctions.output(effect: e, index: 0, count: 4, time: 1.0 / 6, bpm: 120).color!
    #expect(g.r < 0.01 && abs(g.g - 1) < 0.01 && g.b < 0.01)
}

@Test func colorChaseIndexes() {
    let cols = [RGB(r: 1, g: 0, b: 0), RGB(r: 0, g: 1, b: 0), RGB(r: 0, g: 0, b: 1)]
    let e = fx(.colorChase, spread: 0, colors: cols)
    // phase 0.4 at hz 2: t = 0.2
    #expect(EffectFunctions.output(effect: e, index: 0, count: 4, time: 0.2, bpm: 120).color == cols[1])
}

@Test func bounceReverses() {
    let e = fx(.intensityWave, spread: 0, direction: .bounce)
    // base 0.75 at hz 2: t = 0.375
    #expect(abs(EffectFunctions.phase(time: 0.375, bpm: 120, effect: e, index: 0, count: 4) - 0.5) < 1e-9)
}

@Test func circleRadius() {
    for kind in [EffectKind.panTiltCircle] {
        let e = fx(kind, size: 0.6)
        for i in 0..<50 {
            let o = EffectFunctions.output(effect: e, index: i % 4, count: 4, time: Double(i) * 0.137, bpm: 97)
            #expect(abs(hypot(o.panOffset!, o.tiltOffset!) - 0.3) < 1e-9)
        }
    }
}

@Test func strobeFollowsBase() {
    let e = fx(.strobe)
    let on = EffectFunctions.output(effect: e, index: 0, count: 4, time: 0.1, bpm: 120)
    let off = EffectFunctions.output(effect: e, index: 0, count: 4, time: 0.3, bpm: 120)
    #expect(on.strobeOn == true && on.intensity == 1 && off.strobeOn == false && off.intensity == 0)
}
