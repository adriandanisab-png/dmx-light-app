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

    public static let rateMultipliers: [Double] = [0.25, 0.5, 1, 2, 4]

    public init(id: UUID = UUID(), name: String = "", colorHex: String = "#808080", kind: EffectKind,
                fixtureIDs: [UUID], rateMultiplier: Double = 1, size: Double = 1, spread: Double = 1,
                direction: EffectDirection = .forward, colors: [RGB] = []) {
        self.id = id; self.name = name; self.colorHex = colorHex; self.kind = kind
        self.fixtureIDs = fixtureIDs; self.rateMultiplier = rateMultiplier; self.size = size
        self.spread = spread; self.direction = direction; self.colors = colors
    }
}
