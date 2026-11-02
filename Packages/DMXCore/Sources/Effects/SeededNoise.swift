import Foundation

/// Deterministic noise: no system RNG in the render path.
public enum SeededNoise {
    /// splitmix64 → 0..<1
    public static func unit(_ seed: UInt64) -> Double {
        var z = seed &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }

    /// Stable seed from a UUID, an index and a step (FNV-1a over the bytes).
    public static func seed(_ id: UUID, _ index: Int, _ step: Int) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        func mix(_ b: UInt8) { h = (h ^ UInt64(b)) &* 0x100_0000_01b3 }
        withUnsafeBytes(of: id.uuid) { $0.forEach(mix) }
        withUnsafeBytes(of: Int64(index)) { $0.forEach(mix) }
        withUnsafeBytes(of: Int64(step)) { $0.forEach(mix) }
        return h
    }
}
