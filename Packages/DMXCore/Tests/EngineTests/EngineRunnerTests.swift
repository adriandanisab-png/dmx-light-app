import Testing
import Foundation
import ShowModel
import DMXOutput
@testable import Engine

/// Test double that records when each frame arrives (VirtualDMXOutput is final).
final class TimestampingDMXOutput: DMXOutputDevice, @unchecked Sendable {
    private let lock = NSLock()
    private var _times: [TimeInterval] = []
    private var _frames: [DMXFrame] = []
    var isConnected: Bool { true }
    var times: [TimeInterval] { lock.lock(); defer { lock.unlock() }; return _times }
    var frames: [DMXFrame] { lock.lock(); defer { lock.unlock() }; return _frames }
    func send(_ frame: DMXFrame) throws {
        lock.lock(); defer { lock.unlock() }
        _times.append(ProcessInfo.processInfo.systemUptime)
        _frames.append(frame)
    }
}

final class ThrowingDMXOutput: DMXOutputDevice, @unchecked Sendable {
    struct Boom: Error {}
    var isConnected: Bool { false }
    func send(_ frame: DMXFrame) throws { throw Boom() }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock(); private var n = 0
    func bump() { lock.lock(); n += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return n }
}

private func patchInput() -> (EngineInput, Fixture) {
    let t = BuiltInTemplates.all.first { $0.name == "Dimmer" }!
    let f = Fixture(name: "d", typeID: t.id, address: 1)
    return (EngineInput(patch: Patch(types: [t], fixtures: [f])), f)
}

@Test func tickRateApprox() throws {
    let runner = EngineRunner()
    let out = VirtualDMXOutput()
    runner.output = out
    runner.outputEnabled = true
    runner.start()
    Thread.sleep(forTimeInterval: 1.0)
    runner.stop()
    #expect((36...44).contains(out.sentFrames.count), "frames: \(out.sentFrames.count)")
}

@Test func notArmedSendsNothingButRenders() throws {
    let (input, f) = patchInput()
    let runner = EngineRunner()
    let out = VirtualDMXOutput()
    runner.output = out
    runner.update { $0 = input; var p = Programmer(); p.set(channel: 0, to: 77, for: [f.id]); $0.programmer = p }
    runner.start()
    Thread.sleep(forTimeInterval: 0.3)
    runner.stop()
    #expect(out.sentFrames.isEmpty)
    #expect(runner.latestFrame()[1] == 77)
}

@Test func updateAffectsNextFrame() throws {
    let (input, f) = patchInput()
    let runner = EngineRunner()
    runner.update { $0 = input }
    runner.start()
    Thread.sleep(forTimeInterval: 0.1)
    #expect(runner.latestFrame()[1] == 0)
    runner.update { var p = Programmer(); p.set(channel: 0, to: 200, for: [f.id]); $0.programmer = p }
    Thread.sleep(forTimeInterval: 0.15)
    runner.stop()
    #expect(runner.latestFrame()[1] == 200)
}

@Test @MainActor func mainThreadLoadDoesNotStall() throws {
    let runner = EngineRunner()
    let out = TimestampingDMXOutput()
    runner.output = out
    runner.outputEnabled = true
    runner.start()
    Thread.sleep(forTimeInterval: 0.2)
    Thread.sleep(forTimeInterval: 0.3)   // blocks the main thread (this test runs on it)
    Thread.sleep(forTimeInterval: 0.2)
    runner.stop()
    let t = out.times
    #expect(t.count > 10)
    let maxGap = zip(t, t.dropFirst()).map { $1 - $0 }.max() ?? 0
    #expect(maxGap < 0.060, "max gap \(maxGap)")
}

@Test func outputErrorReported() throws {
    let runner = EngineRunner()
    let errors = Counter()
    runner.onOutputError = { _ in errors.bump() }
    runner.output = ThrowingDMXOutput()
    runner.outputEnabled = true
    let (input, f) = patchInput()
    runner.update { $0 = input }
    runner.start()
    Thread.sleep(forTimeInterval: 0.3)
    runner.update { var p = Programmer(); p.set(channel: 0, to: 9, for: [f.id]); $0.programmer = p }
    Thread.sleep(forTimeInterval: 0.2)
    runner.stop()
    #expect(errors.value == 1)
    #expect(runner.latestFrame()[1] == 9)   // keeps rendering
}

@Test func tickHzIsClamped() {
    #expect(EngineRunner(tickHz: 100).tickHz == 44)
    #expect(EngineRunner(tickHz: 1).tickHz == 25)
}
