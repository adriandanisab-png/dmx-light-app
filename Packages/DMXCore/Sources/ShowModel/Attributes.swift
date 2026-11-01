import Foundation

/// Attribute-level edits (intensity, colour, pan/tilt) expressed as channel values for one fixture type.
public enum Attributes {
    static func byte(_ v: Double) -> UInt8 { UInt8((min(max(v, 0), 1) * 255).rounded()) }

    private static func index(of fn: ChannelFunction, in type: FixtureType) -> Int? {
        type.channels.firstIndex { $0.function == fn }
    }

    /// `v` 0…1. With no intensity channel, scales the colour channels already in `values` to `v`.
    public static func setIntensity(_ v: Double, type: FixtureType, into values: inout FixtureValues) {
        let v = min(max(v, 0), 1)
        if let i = index(of: .intensity, in: type) {
            values[i] = byte(v)
            return
        }
        let colourFns: Set<ChannelFunction> = [.red, .green, .blue, .white, .amber, .uv]
        for (i, ch) in type.channels.enumerated() where colourFns.contains(ch.function) {
            if let old = values[i] { values[i] = UInt8((Double(old) * v).rounded()) }
        }
    }

    /// White (if the type has a white channel) = min(r,g,b), subtracted from r, g and b.
    public static func setColor(_ c: RGB, type: FixtureType, into values: inout FixtureValues) {
        var r = min(max(c.r, 0), 1), g = min(max(c.g, 0), 1), b = min(max(c.b, 0), 1)
        if let w = index(of: .white, in: type) {
            let white = min(r, g, b)
            values[w] = byte(white)
            r -= white; g -= white; b -= white
        }
        if let i = index(of: .red, in: type) { values[i] = byte(r) }
        if let i = index(of: .green, in: type) { values[i] = byte(g) }
        if let i = index(of: .blue, in: type) { values[i] = byte(b) }
    }

    /// `pan`/`tilt` 0…1. Uses coarse+fine when the fine channel exists.
    public static func setPanTilt(pan: Double, tilt: Double, type: FixtureType, into values: inout FixtureValues) {
        func put(_ x: Double, coarse: ChannelFunction, fine: ChannelFunction) {
            guard let c = index(of: coarse, in: type) else { return }
            let x = min(max(x, 0), 1)
            if let f = index(of: fine, in: type) {
                let v16 = Int((x * 65535).rounded())
                values[c] = UInt8(v16 >> 8)
                values[f] = UInt8(v16 & 0xFF)
            } else {
                values[c] = byte(x)
            }
        }
        put(pan, coarse: .pan, fine: .panFine)
        put(tilt, coarse: .tilt, fine: .tiltFine)
    }

    /// Colour represented by `values` (white added to each component). White if the type has no colour channels.
    public static func color(of values: FixtureValues, type: FixtureType) -> RGB {
        guard index(of: .red, in: type) != nil || index(of: .green, in: type) != nil
                || index(of: .blue, in: type) != nil || index(of: .white, in: type) != nil
        else { return RGB(r: 1, g: 1, b: 1) }
        func get(_ fn: ChannelFunction) -> Double {
            guard let i = index(of: fn, in: type), let v = values[i] else { return 0 }
            return Double(v) / 255
        }
        let w = get(.white)
        return RGB(r: min(get(.red) + w, 1), g: min(get(.green) + w, 1), b: min(get(.blue) + w, 1))
    }
}
