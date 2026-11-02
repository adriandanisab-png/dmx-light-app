import Foundation
import ShowModel
import DMXOutput
import Effects

public struct RunningEffect: Equatable, Sendable {
    public var effectID: UUID
    public var startedAt: TimeInterval
    /// 0…1 effect master. Overlays run at a lower level and blend over the current look.
    public var level: Double
    public init(effectID: UUID, startedAt: TimeInterval, level: Double = 1) {
        self.effectID = effectID; self.startedAt = startedAt; self.level = level
    }
}

extension Engine {
    /// Effects layer: blends each running effect over what the frame holds so far.
    /// Fixtures lacking the attribute an effect drives are skipped.
    static func applyEffects(_ input: EngineInput, at time: TimeInterval, to frame: inout DMXFrame,
                             types: [UUID: FixtureType], fixtures: [UUID: Fixture]) {
        for running in input.runningEffects {
            guard let effect = input.effects[running.effectID] else { continue }
            let level = min(max(running.level, 0), 1)
            guard level > 0 else { continue }
            let count = effect.fixtureIDs.count
            for (index, fixtureID) in effect.fixtureIDs.enumerated() {
                guard let fixture = fixtures[fixtureID], let type = types[fixture.typeID] else { continue }
                let out = EffectFunctions.output(effect: effect, index: index, count: count,
                                                 time: time - running.startedAt, bpm: input.bpm)
                apply(out, level: level, fixture: fixture, type: type, to: &frame)
            }
        }
    }

    private static func apply(_ out: EffectOutput, level: Double, fixture: Fixture, type: FixtureType,
                              to frame: inout DMXFrame) {
        func addr(_ ch: Int) -> Int? {
            let a = fixture.address + ch
            return (1...DMXFrame.size).contains(a) ? a : nil
        }
        func index(_ fn: ChannelFunction) -> Int? { type.channels.firstIndex { $0.function == fn } }
        func byte(_ v: Double) -> UInt8 { UInt8(max(0, min(255, v.rounded()))) }

        if let target = out.intensity ?? (out.strobeOn == false ? 0 : nil) {
            if let i = index(.intensity), let a = addr(i) {
                frame[a] = byte(Double(frame[a]) * (1 - level) + target * 255 * level)
            } else if !type.channels.contains(where: { $0.function == .intensity }) {
                let t = min(max(target, 0), 1)
                let factor = 1 - level + level * t
                let outs = type.channels.enumerated().compactMap { i, ch in
                    Engine.isIntensity(ch.function, typeHasIntensity: false) ? addr(i) : nil
                }
                // A dark fixture has nothing to scale: treat its base colour as white.
                let dark = outs.allSatisfy { frame[$0] == 0 }
                for a in outs { frame[a] = dark ? byte(255 * level * t) : byte(Double(frame[a]) * factor) }
            }
        }

        if let c = out.color {
            var current: FixtureValues = [:]
            for (i, ch) in type.channels.enumerated() {
                switch ch.function {
                case .red, .green, .blue, .white: if let a = addr(i) { current[i] = frame[a] }
                default: break
                }
            }
            if !current.isEmpty {
                let under = Attributes.color(of: current, type: type)
                let mixed = RGB(r: under.r + (c.r - under.r) * level,
                                g: under.g + (c.g - under.g) * level,
                                b: under.b + (c.b - under.b) * level)
                var values = current
                Attributes.setColor(mixed, type: type, into: &values)
                for (i, v) in values { if let a = addr(i) { frame[a] = v } }
            }
        }

        func shift(_ offset: Double?, coarse: ChannelFunction, fine: ChannelFunction) {
            guard let offset, let c = index(coarse), let ca = addr(c) else { return }
            let fa = index(fine).flatMap(addr)
            let under = fa != nil ? Double(Int(frame[ca]) << 8 | Int(frame[fa!])) / 65535 : Double(frame[ca]) / 255
            let x = min(max(under + offset * level, 0), 1)
            if let fa {
                let v16 = Int((x * 65535).rounded())
                frame[ca] = UInt8(v16 >> 8); frame[fa] = UInt8(v16 & 0xFF)
            } else {
                frame[ca] = byte(x * 255)
            }
        }
        shift(out.panOffset, coarse: .pan, fine: .panFine)
        shift(out.tiltOffset, coarse: .tilt, fine: .tiltFine)
    }
}
