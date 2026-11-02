import Foundation
import ShowModel

/// What an effect asks of one fixture at one instant. nil = no opinion.
public struct EffectOutput: Equatable, Sendable {
    /// 0…1
    public var intensity: Double?
    public var color: RGB?
    /// −0.5…0.5 of full range, scaled by size.
    public var panOffset: Double?
    public var tiltOffset: Double?
    public var strobeOn: Bool?
    public init(intensity: Double? = nil, color: RGB? = nil, panOffset: Double? = nil,
                tiltOffset: Double? = nil, strobeOn: Bool? = nil) {
        self.intensity = intensity; self.color = color; self.panOffset = panOffset
        self.tiltOffset = tiltOffset; self.strobeOn = strobeOn
    }
}
