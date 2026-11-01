import ShowModel

/// What the app believes the console is currently showing (the console never reports back).
public struct ConsoleState: Equatable, Sendable {
    public private(set) var on: Set<ConsoleTarget> = []
    public private(set) var blackout = false
    public init() {}

    /// Symmetric difference between believed state and `target`, ascending by note.
    public func toggles(toReach target: Set<ConsoleTarget>) -> [ConsoleTarget] {
        on.symmetricDifference(target).sorted()
    }

    public mutating func applyToggle(_ t: ConsoleTarget) {
        if t == .blackout { blackout.toggle(); return }
        if on.contains(t) { on.remove(t) } else { on.insert(t) }
    }

    public mutating func reset() { on = []; blackout = false }
}
