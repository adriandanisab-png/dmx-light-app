import Foundation
import ShowModel
import DMXOutput

/// What a fixture looks like on stage, derived from its DMX channels (for the preview only).
public struct FixtureLook: Equatable, Sendable {
    public var color: RGB
    /// 0…1
    public var intensity: Double
    /// nil = no strobe
    public var strobeHz: Double?
    public var panDegrees: Double?
    public var tiltDegrees: Double?

    public init(color: RGB, intensity: Double, strobeHz: Double? = nil,
                panDegrees: Double? = nil, tiltDegrees: Double? = nil) {
        self.color = color; self.intensity = intensity; self.strobeHz = strobeHz
        self.panDegrees = panDegrees; self.tiltDegrees = tiltDegrees
    }
}

public extension FixtureLook {
    static func from(frame: DMXFrame, fixture: Fixture, type: FixtureType) -> FixtureLook {
        func raw(_ fn: ChannelFunction) -> Double? {
            guard let i = type.channels.firstIndex(where: { $0.function == fn }) else { return nil }
            return Double(frame[fixture.address + i])
        }
        let intensity = raw(.intensity).map { $0 / 255 } ?? 1

        let r = raw(.red), g = raw(.green), b = raw(.blue), w = raw(.white)
        let color: RGB
        if r == nil && g == nil && b == nil && w == nil {
            color = RGB(r: 1, g: 1, b: 1)
        } else {
            let white = (w ?? 0) / 255
            color = RGB(r: min((r ?? 0) / 255 + white, 1),
                        g: min((g ?? 0) / 255 + white, 1),
                        b: min((b ?? 0) / 255 + white, 1))
        }

        // Generic guess: 0…9 off, 10…255 maps linearly to 1…20 Hz (real fixtures differ).
        var strobe: Double?
        if let s = raw(.strobe), s >= 10 { strobe = 1 + (s - 10) / 245 * 19 }

        func angle(_ coarse: ChannelFunction, _ fine: ChannelFunction, range: Double) -> Double? {
            guard let c = raw(coarse) else { return nil }
            let fraction = raw(fine).map { (c * 256 + $0) / 65535 } ?? c / 255
            return (fraction - 0.5) * range
        }
        return FixtureLook(
            color: color, intensity: intensity, strobeHz: strobe,
            panDegrees: angle(.pan, .panFine, range: type.panRangeDegrees ?? 540),
            tiltDegrees: angle(.tilt, .tiltFine, range: type.tiltRangeDegrees ?? 270))
    }
}
