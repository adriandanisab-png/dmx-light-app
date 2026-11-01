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
    public var channelCount: Int { channels.count }
    public init(id: UUID = UUID(), name: String, channels: [ChannelDef]) {
        self.id = id; self.name = name; self.channels = channels
    }
}
