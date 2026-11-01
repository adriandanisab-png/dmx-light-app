import Foundation

public enum PatchIssue: Equatable, Sendable {
    case overlap(UUID, UUID), pastEnd(UUID), addressOutOfRange(UUID), unknownType(UUID),
         scannerOutOfRange(UUID), duplicateScanner(Int), emptyType(UUID)
}

public enum PatchError: Error, Equatable { case unknownType, noRoom, invalidCount }

public struct Patch: Codable, Equatable, Sendable {
    public static let universeSize = 512
    public static let scannerRange = 1...12

    public var types: [FixtureType]
    public var fixtures: [Fixture]

    public init(types: [FixtureType] = [], fixtures: [Fixture] = []) {
        self.types = types; self.fixtures = fixtures
    }

    public func type(of fixture: Fixture) -> FixtureType? {
        types.first { $0.id == fixture.typeID }
    }

    /// Never clips silently: every problem is reported. Output order is stable.
    public func validate() -> [PatchIssue] {
        var issues: [PatchIssue] = []
        var spans: [(fixture: Fixture, start: Int, end: Int)] = []
        for f in fixtures {
            guard let t = type(of: f) else { issues.append(.unknownType(f.id)); continue }
            if t.channelCount == 0 { issues.append(.emptyType(f.id)); continue }
            guard (1...Self.universeSize).contains(f.address) else {
                issues.append(.addressOutOfRange(f.id)); continue
            }
            let end = f.address + t.channelCount - 1
            if end > Self.universeSize { issues.append(.pastEnd(f.id)) }
            spans.append((f, f.address, end))
        }
        let sorted = spans.sorted { ($0.start, $0.fixture.id.uuidString) < ($1.start, $1.fixture.id.uuidString) }
        for i in sorted.indices {
            for j in sorted.index(after: i)..<sorted.endIndex {
                if sorted[j].start > sorted[i].end { break }
                issues.append(.overlap(sorted[i].fixture.id, sorted[j].fixture.id))
            }
        }
        var seen = Set<Int>(), dup = Set<Int>()
        for f in fixtures {
            guard let s = f.consoleScanner else { continue }
            if !Self.scannerRange.contains(s) { issues.append(.scannerOutOfRange(f.id)); continue }
            if !seen.insert(s).inserted { dup.insert(s) }
        }
        for s in dup.sorted() { issues.append(.duplicateScanner(s)) }
        return issues
    }

    /// Lowest address where `channelCount` contiguous free channels fit.
    public func nextFreeAddress(channelCount: Int) -> Int? {
        guard channelCount > 0, channelCount <= Self.universeSize else { return nil }
        var used = [Bool](repeating: false, count: Self.universeSize + 1)
        for f in fixtures {
            guard let t = type(of: f), (1...Self.universeSize).contains(f.address) else { continue }
            for a in f.address..<min(f.address + t.channelCount, Self.universeSize + 1) { used[a] = true }
        }
        var run = 0
        for a in 1...Self.universeSize {
            run = used[a] ? 0 : run + 1
            if run == channelCount { return a - channelCount + 1 }
        }
        return nil
    }

    /// Adds `count` fixtures. With `startAddress` they are packed contiguously from there;
    /// otherwise each goes to the lowest free gap. All-or-nothing.
    @discardableResult
    public mutating func addFixtures(typeID: UUID, count: Int, startAddress: Int?, namePrefix: String) throws -> [Fixture] {
        guard count > 0 else { throw PatchError.invalidCount }
        guard let t = types.first(where: { $0.id == typeID }) else { throw PatchError.unknownType }
        var work = self
        var added: [Fixture] = []
        var next = startAddress
        for n in 1...count {
            let addr: Int
            if let s = next {
                guard s >= 1, s + t.channelCount - 1 <= Self.universeSize else { throw PatchError.noRoom }
                addr = s
                next = s + t.channelCount
            } else {
                guard let a = work.nextFreeAddress(channelCount: t.channelCount) else { throw PatchError.noRoom }
                addr = a
            }
            let f = Fixture(name: "\(namePrefix) \(n)", typeID: typeID, address: addr)
            work.fixtures.append(f)
            added.append(f)
        }
        self = work
        return added
    }
}
