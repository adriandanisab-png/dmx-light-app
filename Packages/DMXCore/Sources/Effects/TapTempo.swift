import Foundation

/// Tap-to-set tempo. Taps more than 2 s apart start a new sequence.
public struct TapTempo: Sendable {
    public static let range: ClosedRange<Double> = 20...300
    public private(set) var bpm: Double = 120
    private var taps: [TimeInterval] = []

    public init() {}

    public mutating func tap(at time: TimeInterval) {
        if let last = taps.last, time - last > 2 { taps = [] }
        taps.append(time)
        if taps.count > 5 { taps.removeFirst(taps.count - 5) }
        guard taps.count >= 2 else { return }
        let gaps = zip(taps, taps.dropFirst()).map { $1 - $0 }.sorted()
        let mid = gaps.count / 2
        let median = gaps.count % 2 == 1 ? gaps[mid] : (gaps[mid - 1] + gaps[mid]) / 2
        guard median > 0 else { return }
        bpm = min(max(60 / median, Self.range.lowerBound), Self.range.upperBound)
    }

    public mutating func set(bpm: Double) {
        self.bpm = min(max(bpm, Self.range.lowerBound), Self.range.upperBound)
    }
}
