import Foundation
import ShowModel

/// Test double and "no hardware" sender: records instead of sending.
public final class RecordingMIDISender: MIDISender, @unchecked Sendable {
    private let lock = NSLock()
    private var _isConnected = true
    private var _failNext = false
    private var _sent: [MIDIMessage] = []

    public init() {}

    public var isConnected: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _isConnected }
        set { lock.lock(); defer { lock.unlock() }; _isConnected = newValue }
    }
    public var failNextSend: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _failNext }
        set { lock.lock(); defer { lock.unlock() }; _failNext = newValue }
    }
    public private(set) var sent: [MIDIMessage] {
        get { lock.lock(); defer { lock.unlock() }; return _sent }
        set { lock.lock(); defer { lock.unlock() }; _sent = newValue }
    }

    public func send(_ message: MIDIMessage) throws {
        lock.lock(); defer { lock.unlock() }
        guard _isConnected else { throw ConsoleError.noDestination }
        if _failNext {
            _failNext = false
            throw ConsoleError.sendFailed("simulated failure")
        }
        _sent.append(message)
    }
}
