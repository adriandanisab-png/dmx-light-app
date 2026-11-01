import Foundation

public struct ChannelDef: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var function: ChannelFunction
    public var defaultValue: UInt8
    public var ranges: [ValueRange]
    public init(id: UUID = UUID(), name: String, function: ChannelFunction,
                defaultValue: UInt8 = 0, ranges: [ValueRange] = []) {
        self.id = id; self.name = name; self.function = function
        self.defaultValue = defaultValue; self.ranges = ranges
    }
}

public struct FixtureType: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var channels: [ChannelDef]
    /// Total pan travel in degrees (nil is read as 540).
    public var panRangeDegrees: Double?
    /// Total tilt travel in degrees (nil is read as 270).
    public var tiltRangeDegrees: Double?
    public var channelCount: Int { channels.count }
    public init(id: UUID = UUID(), name: String, channels: [ChannelDef],
                panRangeDegrees: Double? = 540, tiltRangeDegrees: Double? = 270) {
        self.id = id; self.name = name; self.channels = channels
        self.panRangeDegrees = panRangeDegrees; self.tiltRangeDegrees = tiltRangeDegrees
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        channels = try c.decode([ChannelDef].self, forKey: .channels)
        panRangeDegrees = try c.decodeIfPresent(Double.self, forKey: .panRangeDegrees) ?? 540
        tiltRangeDegrees = try c.decodeIfPresent(Double.self, forKey: .tiltRangeDegrees) ?? 270
    }
}
