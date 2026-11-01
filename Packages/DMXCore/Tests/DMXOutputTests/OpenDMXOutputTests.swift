import Testing
import Foundation
import ShowModel
@testable import DMXOutput

enum LinkCall: Equatable {
    case open(String, Int, Int)
    case sendBreak(Int)
    case sleep(Int)
    case write(count: Int, first: [UInt8])
    case drain
    case close
}

final class FakeSerialLink: SerialLink, @unchecked Sendable {
    struct Failure: Error {}
    private let lock = NSLock()
    private var _calls: [LinkCall] = []
    private var writes = 0
    /// 1-based index of the write that throws; nil = never.
    var failWriteNumber: Int?
    /// Number of upcoming open() calls that fail.
    var openFailures = 0
    private var _openCount = 0

    var calls: [LinkCall] { lock.lock(); defer { lock.unlock() }; return _calls }
    var openCount: Int { lock.lock(); defer { lock.unlock() }; return _openCount }
    var writeCount: Int { calls.filter { if case .write = $0 { return true }; return false }.count }

    func open(path: String, baud: Int, stopBits: Int) throws {
        lock.lock(); defer { lock.unlock() }
        _calls.append(.open(path, baud, stopBits)); _openCount += 1
        if openFailures > 0 { openFailures -= 1; throw Failure() }
    }
    func sendBreak(microseconds: Int) throws { lock.lock(); _calls.append(.sendBreak(microseconds)); lock.unlock() }
    func sleep(microseconds: Int) { lock.lock(); _calls.append(.sleep(microseconds)); lock.unlock() }
    func write(_ bytes: [UInt8]) throws {
        lock.lock(); defer { lock.unlock() }
        writes += 1
        if writes == failWriteNumber { throw Failure() }
        _calls.append(.write(count: bytes.count, first: Array(bytes.prefix(2))))
    }
    func drain() throws { lock.lock(); _calls.append(.drain); lock.unlock() }
    func close() { lock.lock(); _calls.append(.close); lock.unlock() }
}

private final class Flag: @unchecked Sendable {
    private let lock = NSLock(); private var n = 0; private var _connectedAtCall: [Bool] = []
    func hit() { lock.lock(); n += 1; lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return n }
}

private func wait(until timeout: TimeInterval, _ cond: () -> Bool) {
    let end = Date().addingTimeInterval(timeout)
    while Date() < end && !cond() { Thread.sleep(forTimeInterval: 0.01) }
}

@Test func openUsesDMXLineSettings() throws {
    let link = FakeSerialLink()
    let out = OpenDMXOutput(path: "/dev/cu.usbserial-X", link: link)
    try out.start()
    out.stop()
    #expect(link.calls.first == .open("/dev/cu.usbserial-X", 250000, 2))
}

@Test func startThrowsWhenOpenFails() {
    let link = FakeSerialLink()
    link.openFailures = 1
    let out = OpenDMXOutput(path: "/dev/x", link: link)
    #expect(throws: DMXDeviceError.self) { try out.start() }
    #expect(!out.isConnected)
}

@Test func frameSequence() throws {
    let link = FakeSerialLink()
    let out = OpenDMXOutput(path: "/dev/x", link: link)
    var frame = DMXFrame()
    frame[1] = 255
    try out.send(frame)
    try out.start()
    // Wait for two full frames rather than a fixed time: CI runners can be slow.
    wait(until: 10.0) { link.writeCount >= 2 }
    out.stop()
    let calls = link.calls.filter { if case .open = $0 { return false }; if case .close = $0 { return false }; return true }
    try #require(calls.count >= 8)
    let expected: [LinkCall] = [.sendBreak(110), .sleep(12), .write(count: 513, first: [0x00, 0xFF]), .drain]
    #expect(Array(calls.prefix(4)) == expected)
    #expect(Array(calls[4..<8]) == expected)
}

@Test func latestFrameWins() throws {
    let link = FakeSerialLink()
    let out = OpenDMXOutput(path: "/dev/x", link: link)
    var a = DMXFrame(); a[1] = 1
    var b = DMXFrame(); b[1] = 2
    try out.send(a); try out.send(b)
    try out.start()
    Thread.sleep(forTimeInterval: 0.05)
    out.stop()
    let writes = link.calls.compactMap { c -> [UInt8]? in if case .write(_, let f) = c { return f }; return nil }
    #expect(writes.first == [0x00, 2])
}

@Test func refreshRateApprox() throws {
    let link = FakeSerialLink()
    let out = OpenDMXOutput(path: "/dev/x", link: link, refreshHz: 30)
    try out.start()
    Thread.sleep(forTimeInterval: 1.0)
    out.stop()
    // Shared CI runners can't hold real-time timing; there we only check frames keep flowing.
    // Steady 30 Hz on real hardware is checked in hardware test part 2.
    let range = ProcessInfo.processInfo.environment["CI"] == nil ? 27...33 : 15...33
    #expect(range.contains(link.writeCount), "writes: \(link.writeCount)")
}

@Test func refreshRateIsClamped() {
    #expect(OpenDMXOutput(path: "/x", link: FakeSerialLink(), refreshHz: 100).refreshHz == 40)
    #expect(OpenDMXOutput(path: "/x", link: FakeSerialLink(), refreshHz: 1).refreshHz == 20)
}

@Test func writeErrorDisconnectsAndRetries() throws {
    let link = FakeSerialLink()
    link.failWriteNumber = 3
    let out = OpenDMXOutput(path: "/dev/x", link: link)
    let lost = Flag()
    out.onDisconnect = { lost.hit() }
    try out.start()
    wait(until: 10.0) { lost.count > 0 }
    #expect(lost.count == 1)
    #expect(!out.isConnected)
    // The adapter stays gone for a moment: reopen must not happen immediately (no busy loop).
    Thread.sleep(forTimeInterval: 0.3)
    #expect(link.openCount == 1)
    wait(until: 10.0) { out.isConnected }
    #expect(link.openCount == 2)
    #expect(out.isConnected)
    Thread.sleep(forTimeInterval: 0.15)
    #expect(link.writeCount > 2)   // transmitting again
    out.stop()
    #expect(lost.count == 1)
}

@Test func keepsRetryingWhileUnplugged() throws {
    let link = FakeSerialLink()
    link.failWriteNumber = 2
    let out = OpenDMXOutput(path: "/dev/x", link: link)
    let lost = Flag()
    out.onDisconnect = { lost.hit() }
    try out.start()
    wait(until: 10.0) { lost.count > 0 }
    link.openFailures = 1          // first reconnect attempt fails too
    wait(until: 10.0) { out.isConnected }
    #expect(link.openCount == 3)   // initial + failed retry + successful retry
    #expect(out.isConnected)
    #expect(lost.count == 1)       // one alert per outage
    out.stop()
}
