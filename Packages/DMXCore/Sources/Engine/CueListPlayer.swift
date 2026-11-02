import Foundation
import ShowModel

public enum CueMode: Sendable { case direct, console }

public enum CueAction: Equatable, Sendable {
    case playDirect(Cue), playConsole(Cue), skipped(Cue, reason: String), end
}

/// Pure cue-list state machine. The app turns its actions into engine updates or console recalls.
public struct CueListPlayer: Sendable {
    private let cues: [Cue]
    private let loops: Bool
    private let snapshotIDs: Set<UUID>
    private let effectIDs: Set<UUID>
    private let lookIDs: Set<UUID>
    /// nil = not started.
    public private(set) var currentIndex: Int?

    public init(list: CueList, show: Show) {
        cues = list.cues.sorted { $0.number < $1.number }
        loops = list.loops
        snapshotIDs = Set(show.snapshots.map(\.id))
        effectIDs = Set(show.effects.map(\.id))
        lookIDs = Set(show.console.looks.map(\.id))
    }

    public var currentCue: Cue? { currentIndex.map { cues[$0] } }

    /// A part is usable when it exists and (for Direct) at least one referenced ID is still in the show.
    private func usable(_ cue: Cue, _ mode: CueMode) -> Bool {
        switch mode {
        case .direct:
            guard let d = cue.direct else { return false }
            if d.snapshotIDs.isEmpty && d.effectIDs.isEmpty { return true }
            return d.snapshotIDs.contains(snapshotIDs) || d.effectIDs.contains(effectIDs)
        case .console:
            switch cue.console {
            case nil: return false
            case let .look(id): return lookIDs.contains(id)
            case .targets: return true
            }
        }
    }

    private func reason(_ cue: Cue, _ mode: CueMode) -> String {
        let part = mode == .direct ? cue.direct != nil : cue.console != nil
        let name = mode == .direct ? "direct" : "console"
        return part ? "\(name) part missing items" : "no \(name) part"
    }

    private func play(_ cue: Cue, _ mode: CueMode) -> CueAction {
        mode == .direct ? .playDirect(cue) : .playConsole(cue)
    }

    /// Walks from `start` in `step` direction, skipping unusable cues; stops at the first playable one.
    private mutating func walk(from start: Int, step: Int, mode: CueMode) -> [CueAction] {
        guard !cues.isEmpty else { return [.end] }
        var actions: [CueAction] = []
        var i = start
        var visited = 0
        while visited < cues.count {
            if !(0..<cues.count).contains(i) {
                guard loops else { actions.append(.end); return actions }
                i = step > 0 ? 0 : cues.count - 1
            }
            visited += 1
            if usable(cues[i], mode) {
                currentIndex = i
                actions.append(play(cues[i], mode))
                return actions
            }
            actions.append(.skipped(cues[i], reason: reason(cues[i], mode)))
            i += step
        }
        actions.append(.end)
        return actions
    }

    public mutating func go(mode: CueMode) -> [CueAction] {
        walk(from: (currentIndex ?? -1) + 1, step: 1, mode: mode)
    }

    public mutating func back(mode: CueMode) -> [CueAction] {
        guard let cur = currentIndex else { return [] }
        return walk(from: cur - 1, step: -1, mode: mode)
    }

    /// Plays the cue with that number (skipping forward if it has no usable part). Unknown number: no actions.
    public mutating func jump(to number: Double, mode: CueMode) -> [CueAction] {
        guard let i = cues.firstIndex(where: { $0.number == number }) else { return [] }
        return walk(from: i, step: 1, mode: mode)
    }

    /// True once the current cue's fade plus its auto-follow delay has passed.
    public func nextAutoFollow(at time: TimeInterval, cueStartedAt: TimeInterval) -> Bool {
        guard let cue = currentCue, case let .auto(after) = cue.follow else { return false }
        return time >= cueStartedAt + cue.fade + after
    }
}

private extension Array where Element == UUID {
    func contains(_ set: Set<UUID>) -> Bool { contains { set.contains($0) } }
}
