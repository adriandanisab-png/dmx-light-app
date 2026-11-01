import Foundation

/// Records frames instead of driving hardware. Used for previews and tests.
public final class VirtualDMXOutput: DMXOutputDevice, @unchecked Sendable {
    private let lock = NSLock()
    private var _frames: [DMXFrame] = []
    public init() {}
    public var isConnected: Bool { true }
    public private(set) var sentFrames: [DMXFrame] {
        get { lock.lock(); defer { lock.unlock() }; return _frames }
        set { lock.lock(); defer { lock.unlock() }; _frames = newValue }
    }
    public func send(_ frame: DMXFrame) throws {
        lock.lock(); defer { lock.unlock() }
        _frames.append(frame)
    }
}
