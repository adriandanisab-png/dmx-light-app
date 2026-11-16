import Foundation
import ShowModel
import DMXOutput

/// Pure frame renderer: defaults → playbacks (HTP intensity / LTP rest, scaled by level) → fixture faders (HTP) → effects → programmer → grand master → blackout.
public enum Engine {
    public static func render(_ input: EngineInput, at time: TimeInterval) -> DMXFrame {
        let patch = input.patch
        var frame = PatchWriter.defaults(for: patch)
        let typeByID = Dictionary(patch.types.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let fixtureByID = Dictionary(patch.fixtures.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        func address(_ fixtureID: UUID, _ channel: Int) -> (addr: Int, type: FixtureType)? {
            guard let f = fixtureByID[fixtureID], let t = typeByID[f.typeID],
                  (0..<t.channelCount).contains(channel) else { return nil }
            let a = f.address + channel
            return (1...DMXFrame.size).contains(a) ? (a, t) : nil
        }

        func progress(_ pb: PlaybackState) -> Double {
            pb.fade <= 0 ? 1 : min(max((time - pb.startedAt) / pb.fade, 0), 1)
        }

        // Channels no active snapshot records fade from the oldest playback's start frame back to
        // their defaults, so replacing look A with look B fades A's lights out instead of cutting them.
        let playbacks = input.playbacks.filter { $0.level > 0 }
        if let first = playbacks.first {
            var recorded = Set<Int>()
            for pb in playbacks {
                for (fixtureID, values) in input.snapshots[pb.snapshotID]?.values ?? [:] {
                    for ch in values.keys { if let (addr, _) = address(fixtureID, ch) { recorded.insert(addr) } }
                }
            }
            let p = progress(first)
            for addr in 1...DMXFrame.size where !recorded.contains(addr) {
                let from = Double(first.fadeFrom[addr]), to = Double(frame[addr])
                if from != to { frame[addr] = UInt8(max(0, min(255, (from + (to - from) * p).rounded()))) }
            }
        }

        for pb in playbacks {
            guard let snap = input.snapshots[pb.snapshotID] else { continue }
            let p = progress(pb)
            let level = min(pb.level, 1)
            let typeHasIntensity: (FixtureType) -> Bool = { t in t.channels.contains { $0.function == .intensity } }
            for (fixtureID, values) in snap.values {
                for (ch, target) in values {
                    guard let (addr, type) = address(fixtureID, ch) else { continue }
                    let from = Double(pb.fadeFrom[addr])
                    let scaled = Engine.isIntensity(type.channels[ch].function, typeHasIntensity: typeHasIntensity(type))
                        ? Double(target) * level : Double(target)
                    let v = UInt8(max(0, min(255, (from + (scaled - from) * p).rounded())))
                    // HTP only for true intensity channels; colour channels of dimmer-less types stay LTP
                    // (merging RGB channel-wise by HTP would mix colours). GM still scales them below.
                    if type.channels[ch].function == .intensity {
                        frame[addr] = max(frame[addr], v)
                    } else {
                        frame[addr] = v
                    }
                }
            }
        }

        applyFixtureLevels(input.fixtureLevels, to: &frame, types: typeByID, fixtures: fixtureByID)
        applyEffects(input, at: time, to: &frame, types: typeByID, fixtures: fixtureByID)

        for (fixtureID, values) in input.programmer.values {
            for (ch, v) in values {
                if let (addr, _) = address(fixtureID, ch) { frame[addr] = v }
            }
        }

        let gm = min(max(input.grandMaster, 0), 1)
        if input.blackout || gm < 1 {
            for f in patch.fixtures {
                guard let t = typeByID[f.typeID] else { continue }
                let hasInt = t.channels.contains { $0.function == .intensity }
                for (i, ch) in t.channels.enumerated() where isIntensity(ch.function, typeHasIntensity: hasInt) {
                    let a = f.address + i
                    guard (1...DMXFrame.size).contains(a) else { continue }
                    frame[a] = input.blackout ? 0 : UInt8((Double(frame[a]) * gm).rounded())
                }
            }
        }
        return frame
    }
}
