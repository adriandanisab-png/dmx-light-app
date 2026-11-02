import Foundation

/// What a cue does in Direct mode: snapshots to play and effects to run.
public struct DirectCuePart: Codable, Hashable, Sendable {
    public var snapshotIDs: [UUID]
    public var effectIDs: [UUID]
    public init(snapshotIDs: [UUID] = [], effectIDs: [UUID] = []) {
        self.snapshotIDs = snapshotIDs; self.effectIDs = effectIDs
    }
}

/// What a cue does in Console mode: a saved console look, or loose cell targets.
public enum ConsoleCuePart: Codable, Hashable, Sendable {
    case look(UUID)
    case targets(Set<ConsoleTarget>)
}

public enum CueFollow: Codable, Hashable, Sendable {
    case manual
    /// Seconds after the fade completes.
    case auto(after: Double)
}

public struct Cue: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var number: Double
    public var name: String
    /// Seconds, 0…600.
    public var fade: Double
    public var follow: CueFollow
    public var direct: DirectCuePart?
    public var console: ConsoleCuePart?
    public init(id: UUID = UUID(), number: Double, name: String = "", fade: Double = 1,
                follow: CueFollow = .manual, direct: DirectCuePart? = nil, console: ConsoleCuePart? = nil) {
        self.id = id; self.number = number; self.name = name; self.fade = fade
        self.follow = follow; self.direct = direct; self.console = console
    }
}

public struct CueList: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var cues: [Cue]
    public var loops: Bool
    public init(id: UUID = UUID(), name: String, cues: [Cue] = [], loops: Bool = false) {
        self.id = id; self.name = name; self.cues = cues; self.loops = loops
    }
}
