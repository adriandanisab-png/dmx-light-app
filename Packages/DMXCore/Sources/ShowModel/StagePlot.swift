import Foundation

public struct StagePlot: Codable, Hashable, Sendable {
    public var widthMeters: Double
    public var depthMeters: Double
    /// File inside the .dmxshow package.
    public var backgroundFileName: String?

    public init(widthMeters: Double = 10, depthMeters: Double = 6, backgroundFileName: String? = nil) {
        self.widthMeters = widthMeters; self.depthMeters = depthMeters
        self.backgroundFileName = backgroundFileName
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        widthMeters = try c.decodeIfPresent(Double.self, forKey: .widthMeters) ?? 10
        depthMeters = try c.decodeIfPresent(Double.self, forKey: .depthMeters) ?? 6
        backgroundFileName = try c.decodeIfPresent(String.self, forKey: .backgroundFileName)
    }
}
