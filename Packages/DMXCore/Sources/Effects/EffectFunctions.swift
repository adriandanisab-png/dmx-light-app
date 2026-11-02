import Foundation
import ShowModel

/// Pure, deterministic effect maths.
public enum EffectFunctions {
    static func frac(_ x: Double) -> Double { x - x.rounded(.down) }

    static func base(time: TimeInterval, bpm: Double, effect: Effect) -> Double {
        time * bpm / 60 * effect.rateMultiplier
    }

    /// 0..<1
    public static func phase(time: TimeInterval, bpm: Double, effect: Effect, index: Int, count: Int) -> Double {
        let b = base(time: time, bpm: bpm, effect: effect)
        let o = effect.spread * Double(index) / Double(max(count, 1))
        switch effect.direction {
        case .forward: return frac(b - o)
        case .backward: return frac(b + o)
        case .bounce:
            let p = frac(b - o)
            return p < 0.5 ? p * 2 : 2 - p * 2
        }
    }

    public static func output(effect: Effect, index: Int, count: Int, time: TimeInterval, bpm: Double) -> EffectOutput {
        let p = phase(time: time, bpm: bpm, effect: effect, index: index, count: count)
        let b = base(time: time, bpm: bpm, effect: effect)
        var out = EffectOutput()
        switch effect.kind {
        case .intensityChase:
            out.intensity = p < max(1 / Double(max(count, 1)), 0.05) ? effect.size : 0
        case .intensityWave:
            out.intensity = effect.size * (0.5 - 0.5 * cos(2 * .pi * p))
        case .sparkle:
            let step = Int(b.rounded(.down))
            let n = SeededNoise.unit(SeededNoise.seed(effect.id, index, step))
            out.intensity = n < 0.2 * effect.size ? 1 : 0
        case .rainbow:
            out.color = hsv(h: p, s: effect.size, v: 1)
        case .colorChase:
            if !effect.colors.isEmpty { out.color = effect.colors[Int(p * Double(effect.colors.count)) % effect.colors.count] }
        case .strobe:
            let on = frac(b) < 0.5
            out.strobeOn = on
            out.intensity = on ? 1 : 0
        case .panTiltCircle:
            out.panOffset = 0.5 * effect.size * cos(2 * .pi * p)
            out.tiltOffset = 0.5 * effect.size * sin(2 * .pi * p)
        case .figure8:
            out.panOffset = 0.5 * effect.size * sin(2 * .pi * p)
            out.tiltOffset = 0.5 * effect.size * sin(4 * .pi * p) / 2
        }
        return out
    }

    static func hsv(h: Double, s: Double, v: Double) -> RGB {
        let h6 = frac(h) * 6, i = Int(h6) % 6, f = h6 - h6.rounded(.down)
        let p = v * (1 - s), q = v * (1 - s * f), t = v * (1 - s * (1 - f))
        switch i {
        case 0: return RGB(r: v, g: t, b: p)
        case 1: return RGB(r: q, g: v, b: p)
        case 2: return RGB(r: p, g: v, b: t)
        case 3: return RGB(r: p, g: q, b: v)
        case 4: return RGB(r: t, g: p, b: v)
        default: return RGB(r: v, g: p, b: q)
        }
    }
}
