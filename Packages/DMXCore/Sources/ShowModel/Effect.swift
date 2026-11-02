import Foundation

public enum EffectKind: String, Codable, CaseIterable, Sendable {
    case intensityChase, intensityWave, sparkle, rainbow, colorChase, strobe, panTiltCircle, figure8
}

public enum EffectDirection: String, Codable, Sendable { case forward, backward, bounce }

/// A parametric effect over an ordered list of fixtures (order = chase order).
public struct Effect: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var colorHex: String
    public var kind: EffectKind
    public var fixtureIDs: [UUID]
    /// One of 0.25, 0.5, 1, 2, 4.
    public var rateMultiplier: Double
    /// 0…1
    public var size: Double
    /// 0…1 phase spread across fixtures.
    public var spread: Double
    public var direction: EffectDirection
    /// colorChase only, ≥ 2.
    public var colors: [RGB]
    /// Overlays stack over the look; non-overlays (chases) are exclusive in the UI.
    public var overlay: Bool

    public static let rateMultipliers: [Double] = [0.25, 0.5, 1, 2, 4]

    public init(id: UUID = UUID(), name: String = "", colorHex: String = "#808080", kind: EffectKind,
                fixtureIDs: [UUID], rateMultiplier: Double = 1, size: Double = 1, spread: Double = 1,
                direction: EffectDirection = .forward, colors: [RGB] = [], overlay: Bool = false) {
        self.id = id; self.name = name; self.colorHex = colorHex; self.kind = kind
        self.fixtureIDs = fixtureIDs; self.rateMultiplier = rateMultiplier; self.size = size
        self.spread = spread; self.direction = direction; self.colors = colors; self.overlay = overlay
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        colorHex = try c.decode(String.self, forKey: .colorHex)
        kind = try c.decode(EffectKind.self, forKey: .kind)
        fixtureIDs = try c.decode([UUID].self, forKey: .fixtureIDs)
        rateMultiplier = try c.decode(Double.self, forKey: .rateMultiplier)
        size = try c.decode(Double.self, forKey: .size)
        spread = try c.decode(Double.self, forKey: .spread)
        direction = try c.decode(EffectDirection.self, forKey: .direction)
        colors = try c.decode([RGB].self, forKey: .colors)
        overlay = try c.decodeIfPresent(Bool.self, forKey: .overlay) ?? false
    }
}
