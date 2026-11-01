import Foundation
import os
import ShowModel
import DMXOutput

/// Ticks `Engine.render` on a dedicated high-priority queue and hands frames to the output device.
/// Never touches the main actor; shared state is guarded by an unfair lock.
public final class EngineRunner: @unchecked Sendable {
    public static let tickRange: ClosedRange<Double> = 25...44

    private struct State {
        var input = EngineInput()
        var output: DMXOutputDevice?
        var outputEnabled = false
        var latest = DMXFrame()
        var onOutputError: (@Sendable (Error) -> Void)?
        var errorReported = false
        var timer: DispatchSourceTimer?
    }

    public let tickHz: Double
    private let clock: @Sendable () -> TimeInterval
    private let state = OSAllocatedUnfairLock(initialState: State())
    private let queue = DispatchQueue(label: "dmxbridge.engine", qos: .userInteractive)

    public init(tickHz: Double = 40,
                clock: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.tickHz = min(max(tickHz, Self.tickRange.lowerBound), Self.tickRange.upperBound)
        self.clock = clock
    }

    deinit { stop() }

    /// The runner's clock; use it for `PlaybackState.startedAt`.
    public func now() -> TimeInterval { clock() }

    public func update(_ mutate: @Sendable (inout EngineInput) -> Void) {
        state.withLock { mutate(&$0.input) }
    }

    /// Current input (for building `fadeFrom` etc.).
    public func currentInput() -> EngineInput { state.withLock { $0.input } }

    /// nil = preview only.
    public var output: DMXOutputDevice? {
        get { state.withLock { $0.output } }
        set { state.withLock { $0.output = newValue; $0.errorReported = false } }
    }

    /// The arm switch.
    public var outputEnabled: Bool {
        get { state.withLock { $0.outputEnabled } }
        set { state.withLock { $0.outputEnabled = newValue; if newValue { $0.errorReported = false } } }
    }

    public var onOutputError: (@Sendable (Error) -> Void)? {
        get { state.withLock { $0.onOutputError } }
        set { state.withLock { $0.onOutputError = newValue } }
    }

    public func latestFrame() -> DMXFrame { state.withLock { $0.latest } }

    public func start() {
        let already = state.withLock { $0.timer != nil }
        if already { return }
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        let period = 1.0 / tickHz
        timer.schedule(deadline: .now(), repeating: period, leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in self?.tick() }
        state.withLock { $0.timer = timer }
        timer.resume()
    }

    public func stop() {
        let t = state.withLock { s -> DispatchSourceTimer? in
            let t = s.timer; s.timer = nil; return t
        }
        t?.cancel()
    }

    private func tick() {
        let time = clock()
        let input = state.withLock { $0.input }
        let frame = Engine.render(input, at: time)
        let (out, enabled) = state.withLock { s -> (DMXOutputDevice?, Bool) in
            s.latest = frame
            return (s.output, s.outputEnabled)
        }
        guard enabled, let out else { return }
        do {
            try out.send(frame)
            state.withLock { $0.errorReported = false }
        } catch {
            let handler = state.withLock { s -> (@Sendable (Error) -> Void)? in
                if s.errorReported { return nil }
                s.errorReported = true
                return s.onOutputError
            }
            handler?(error)
        }
    }
}
