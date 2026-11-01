import Foundation

public enum ConsoleError: Error, Equatable {
    case bankNotReachable(Int), sceneOutOfRange(Int), chaseOutOfRange(Int),
         midiChannelOutOfRange(Int), notArmed, sendFailed(String), noDestination
}

public enum ConsoleTarget: Hashable, Codable, Sendable, Comparable {
    case scene(bank: Int, scene: Int)
    case chase(Int)
    case blackout

    public static let blackoutNote: UInt8 = 126

    /// Spec 5.1: scene = (b-1)*8 + (s-1); chase c = 119 + c; blackout = 126.
    /// Rejects anything MIDI cannot reach, before any MIDI is built.
    public func noteNumber() throws -> UInt8 {
        switch self {
        case let .scene(bank, scene):
            guard (1...15).contains(bank) else { throw ConsoleError.bankNotReachable(bank) }
            guard (1...8).contains(scene) else { throw ConsoleError.sceneOutOfRange(scene) }
            return UInt8((bank - 1) * 8 + (scene - 1))
        case let .chase(c):
            guard (1...6).contains(c) else { throw ConsoleError.chaseOutOfRange(c) }
            return UInt8(119 + c)
        case .blackout:
            return Self.blackoutNote
        }
    }

    /// 120 scenes + 6 chases + blackout, ascending note.
    public static var allReachable: [ConsoleTarget] {
        var all: [ConsoleTarget] = []
        for b in 1...15 { for s in 1...8 { all.append(.scene(bank: b, scene: s)) } }
        for c in 1...6 { all.append(.chase(c)) }
        all.append(.blackout)
        return all
    }

    private var sortKey: Int {
        (try? Int(noteNumber())) ?? Int.max
    }

    public static func < (a: ConsoleTarget, b: ConsoleTarget) -> Bool {
        if a.sortKey != b.sortKey { return a.sortKey < b.sortKey }
        // Unreachable targets: stable fallback.
        return String(describing: a) < String(describing: b)
    }
}
