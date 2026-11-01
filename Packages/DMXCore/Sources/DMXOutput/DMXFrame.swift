public struct DMXFrame: Equatable, Sendable {
    public static let size = 512
    private var storage = [UInt8](repeating: 0, count: DMXFrame.size)
    public init() {}

    /// 1-based. Out-of-range get returns 0; out-of-range set is ignored.
    public subscript(address: Int) -> UInt8 {
        get { (1...Self.size).contains(address) ? storage[address - 1] : 0 }
        set { if (1...Self.size).contains(address) { storage[address - 1] = newValue } }
    }

    public var bytes: [UInt8] { storage }
}
