import Foundation
import DMXOutput
import ShowModel

extension Engine {
    /// True for channels that merge HTP and that grand master / blackout scale:
    /// the intensity channel, or (for types without one) the colour channels.
    public static func isIntensity(_ fn: ChannelFunction, typeHasIntensity: Bool) -> Bool {
        if fn == .intensity { return true }
        guard !typeHasIntensity else { return false }
        switch fn {
        case .red, .green, .blue, .white, .amber, .uv: return true
        default: return false
        }
    }
}

extension Engine {
    /// Fixture faders: an HTP layer. A fixture with an intensity channel is raised to at least the level.
    /// A dimmer-less one lights white when dark, else keeps its hue and has its brightness raised to the level.
    static func applyFixtureLevels(_ levels: [UUID: Double], colors: [UUID: RGB] = [:], to frame: inout DMXFrame,
                                   types: [UUID: FixtureType], fixtures: [UUID: Fixture]) {
        for (id, raw) in levels {
            let level = min(max(raw, 0), 1)
            guard level > 0, let fixture = fixtures[id], let type = types[fixture.typeID] else { continue }
            func addr(_ ch: Int) -> Int? {
                let a = fixture.address + ch
                return (1...DMXFrame.size).contains(a) ? a : nil
            }
            let target = level * 255
            if let i = type.channels.firstIndex(where: { $0.function == .intensity }) {
                if let a = addr(i) { frame[a] = max(frame[a], UInt8(target.rounded())) }
                continue
            }
            let colour = type.channels.enumerated().compactMap { i, ch in
                isIntensity(ch.function, typeHasIntensity: false) ? addr(i) : nil
            }
            guard !colour.isEmpty else { continue }
            let peak = colour.map { Double(frame[$0]) }.max() ?? 0
            if peak == 0 {
                let c = colors[id] ?? RGB(r: 1, g: 1, b: 1)
                var values: FixtureValues = [:]
                Attributes.setColor(RGB(r: c.r * level, g: c.g * level, b: c.b * level), type: type, into: &values)
                for (i, v) in values { if let a = addr(i) { frame[a] = v } }
            } else if peak < target {
                for a in colour {
                    frame[a] = UInt8(min(255, (Double(frame[a]) / peak * target).rounded()))
                }
            }
        }
    }

    /// Live colour per fixture: replaces the colour from playbacks. A fixture with an intensity channel just
    /// gets the colour; a dimmer-less one keeps its current brightness (dark stays dark until a fader raises it).
    static func applyFixtureColors(_ colors: [UUID: RGB], to frame: inout DMXFrame,
                                   types: [UUID: FixtureType], fixtures: [UUID: Fixture]) {
        for (id, c) in colors {
            guard let fixture = fixtures[id], let type = types[fixture.typeID] else { continue }
            func addr(_ ch: Int) -> Int? {
                let a = fixture.address + ch
                return (1...DMXFrame.size).contains(a) ? a : nil
            }
            var scale = 1.0
            if !type.channels.contains(where: { $0.function == .intensity }) {
                let colour = type.channels.enumerated().compactMap { i, ch in
                    isIntensity(ch.function, typeHasIntensity: false) ? addr(i) : nil
                }
                scale = (colour.map { Double(frame[$0]) }.max() ?? 0) / 255
            }
            var values: FixtureValues = [:]
            Attributes.setColor(RGB(r: c.r * scale, g: c.g * scale, b: c.b * scale), type: type, into: &values)
            for (i, v) in values { if let a = addr(i) { frame[a] = v } }
        }
    }
}
