import Foundation

/// channel index (0-based within the fixture) → value
public typealias FixtureValues = [Int: UInt8]

/// Colour with components 0…1.
public struct RGB: Codable, Hashable, Sendable {
    public var r, g, b: Double
    public init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
}
