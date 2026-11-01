import Foundation

public enum ChannelFunction: String, Codable, CaseIterable, Sendable {
    case intensity, red, green, blue, white, amber, uv, colorWheel, gobo,
         pan, panFine, tilt, tiltFine, strobe, speed, macro, generic
}

public struct ValueRange: Codable, Hashable, Sendable {
    public var from: UInt8
    public var to: UInt8
    public var label: String
    public init(from: UInt8, to: UInt8, label: String) {
        self.from = from; self.to = to; self.label = label
    }
}
