import Foundation
import ShowModel
import DMXOutput

/// Pure frame renderer: defaults → playbacks (HTP intensity / LTP rest) → programmer → grand master → blackout.
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

        for pb in input.playbacks {
            guard let snap = input.snapshots[pb.snapshotID] else { continue }
            let p: Double = pb.fade <= 0 ? 1 : min(max((time - pb.startedAt) / pb.fade, 0), 1)
            for (fixtureID, values) in snap.values {
                for (ch, target) in values {
                    guard let (addr, type) = address(fixtureID, ch) else { continue }
                    let from = Double(pb.fadeFrom[addr])
                    let v = UInt8(max(0, min(255, (from + (Double(target) - from) * p).rounded())))
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
