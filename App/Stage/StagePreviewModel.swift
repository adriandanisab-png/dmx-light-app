import Foundation
import ShowModel
import DMXOutput
import Engine

/// Pure helpers for the preview. Called on the main thread only, at display rate.
enum StagePreviewModel {
    /// Strobe is drawn at no more than 10 Hz regardless of the fixture's rate.
    static let maxStrobeDrawHz = 10.0

    /// Where each fixture is drawn: its position, or lined up across the front of the stage when it has none
    /// (far enough from the edge that the glyph and its name stay visible).
    static func positions(for patch: Patch) -> [UUID: StagePoint] {
        let unplaced = patch.fixtures.filter { $0.stagePosition == nil }
        var result: [UUID: StagePoint] = [:]
        for f in patch.fixtures { if let p = f.stagePosition { result[f.id] = p } }
        for (i, f) in unplaced.enumerated() {
            result[f.id] = StagePoint(x: (Double(i) + 1) / (Double(unplaced.count) + 1), y: 0.8)
        }
        return result
    }

    static func looks(frame: DMXFrame, patch: Patch) -> [UUID: FixtureLook] {
        var types: [UUID: FixtureType] = [:]
        for t in patch.types { types[t.id] = t }
        var result: [UUID: FixtureLook] = [:]
        for f in patch.fixtures {
            guard let t = types[f.typeID] else { continue }
            result[f.id] = FixtureLook.from(frame: frame, fixture: f, type: t)
        }
        return result
    }

    /// Whether a strobing fixture is in its "on" half-cycle at `time`.
    static func strobeVisible(hz: Double?, time: TimeInterval) -> Bool {
        guard let hz else { return true }
        let f = min(max(hz, 0.1), maxStrobeDrawHz)
        return Int((time * 2 * f).rounded(.down)) % 2 == 0
    }

    /// Beam direction in radians (0 = up, clockwise) from pan, and length in points from tilt.
    static func beam(look: FixtureLook, radius: Double) -> (angle: Double, length: Double)? {
        guard let pan = look.panDegrees, let tilt = look.tiltDegrees else { return nil }
        let t = min(max((tilt + 135) / 270, 0), 1)
        return (pan * .pi / 180, radius * 1.2 + t * radius * 4)
    }

    static func positionText(_ p: StagePoint) -> String {
        String(format: "x=%.3f y=%.3f", p.x, p.y)
    }
}
