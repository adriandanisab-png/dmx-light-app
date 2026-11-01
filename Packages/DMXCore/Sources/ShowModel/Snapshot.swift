import Foundation

public struct Snapshot: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var colorHex: String
    /// fixture id → channels that are recorded
    public var values: [UUID: FixtureValues]
    /// Seconds.
    public var defaultFade: Double

    public init(id: UUID = UUID(), name: String, colorHex: String,
                values: [UUID: FixtureValues] = [:], defaultFade: Double = 1.0) {
        self.id = id; self.name = name; self.colorHex = colorHex
        self.values = values; self.defaultFade = defaultFade
    }
}
