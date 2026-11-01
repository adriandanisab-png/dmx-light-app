import Foundation

/// Open DMX (FTDI, e.g. DSD TECH SH-RS09B) driver with its own send loop:
/// break → MAB → start code + 512 bytes, always sending the latest frame.
/// 250000 baud, 8N2. On a write error it reports once, closes the port and retries opening every second.
public final class OpenDMXOutput: DMXOutputDevice, @unchecked Sendable {
    public static let refreshRange: ClosedRange<Double> = 20...40
    public static let breakMicroseconds = 110
    public static let mabMicroseconds = 12
    static let retryInterval: TimeInterval = 1.0

    public let path: String
    public let refreshHz: Double
    private let link: SerialLink
    private let lock = NSLock()
    private var latest = DMXFrame()
    private var _connected = false
    private var running = false
    private var thread: Thread?
    private let finished = DispatchSemaphore(value: 0)
    private var _onDisconnect: (@Sendable () -> Void)?

    public init(path: String, link: SerialLink = POSIXSerialLink(), refreshHz: Double = 30) {
        self.path = path
        self.link = link
        self.refreshHz = min(max(refreshHz, Self.refreshRange.lowerBound), Self.refreshRange.upperBound)
    }

    deinit { stop() }

    public var onDisconnect: (@Sendable () -> Void)? {
        get { lock.lock(); defer { lock.unlock() }; return _onDisconnect }
        set { lock.lock(); _onDisconnect = newValue; lock.unlock() }
    }

    public var isConnected: Bool { lock.lock(); defer { lock.unlock() }; return _connected }

    private var isRunning: Bool { lock.lock(); defer { lock.unlock() }; return running }
    private func setConnected(_ v: Bool) { lock.lock(); _connected = v; lock.unlock() }

    /// Only stores the latest frame; the internal thread transmits it.
    public func send(_ frame: DMXFrame) throws {
        lock.lock(); latest = frame; lock.unlock()
    }

    /// Opens the port (throws `openFailed`) and starts the send loop.
    public func start() throws {
        lock.lock()
        if running { lock.unlock(); return }
        lock.unlock()
        do { try link.open(path: path, baud: 250_000, stopBits: 2) } catch {
            throw (error as? DMXDeviceError) ?? DMXDeviceError.openFailed("\(error)")
        }
        let t = Thread { [self] in loop() }
        t.name = "dmxbridge.opendmx"
        t.qualityOfService = .userInteractive
        lock.lock(); running = true; _connected = true; thread = t; lock.unlock()
        t.start()
    }

    public func stop() {
        lock.lock()
        guard running else { lock.unlock(); return }
        running = false
        let t = thread; thread = nil
        lock.unlock()
        if t != nil { _ = finished.wait(timeout: .now() + 2) }
        link.close()
        setConnected(false)
    }

    private func currentFrame() -> DMXFrame { lock.lock(); defer { lock.unlock() }; return latest }

    private func loop() {
        defer { finished.signal() }
        let period = 1.0 / refreshHz
        var connected = true
        var deadline = Date()
        while isRunning {
            if !connected {
                // Adapter lost: poll for it at 1 Hz (sleep in slices so stop() stays responsive).
                var waited = 0.0
                while isRunning && waited < Self.retryInterval { Thread.sleep(forTimeInterval: 0.05); waited += 0.05 }
                guard isRunning else { break }
                do {
                    try link.open(path: path, baud: 250_000, stopBits: 2)
                    connected = true
                    deadline = Date()
                    setConnected(true)
                } catch {
                    link.close()
                }
                continue
            }
            do {
                try link.sendBreak(microseconds: Self.breakMicroseconds)
                link.sleep(microseconds: Self.mabMicroseconds)
                try link.write([0x00] + currentFrame().bytes)
                try link.drain()
            } catch {
                connected = false
                setConnected(false)
                link.close()
                onDisconnect?()
                continue
            }
            // Absolute deadlines: sleep overshoot doesn't accumulate into a lower refresh rate.
            deadline = deadline.addingTimeInterval(period)
            let remaining = deadline.timeIntervalSinceNow
            if remaining > 0 { Thread.sleep(forTimeInterval: remaining) } else { deadline = Date() }
        }
    }
}
