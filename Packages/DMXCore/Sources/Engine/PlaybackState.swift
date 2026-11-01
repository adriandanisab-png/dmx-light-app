import Foundation
import ShowModel
import DMXOutput

public struct PlaybackState: Equatable, Sendable {
    public var snapshotID: UUID
    public var startedAt: TimeInterval
    public var fade: Double
    /// Frame on screen when the recall started (an interrupted fade continues from the current value).
    public var fadeFrom: DMXFrame

    public init(snapshotID: UUID, startedAt: TimeInterval, fade: Double, fadeFrom: DMXFrame) {
        self.snapshotID = snapshotID; self.startedAt = startedAt
        self.fade = fade; self.fadeFrom = fadeFrom
    }
}

public struct EngineInput: Sendable {
    public var patch: Patch
    public var snapshots: [UUID: Snapshot]
    /// Activation order, oldest first.
    public var playbacks: [PlaybackState]
    public var programmer: Programmer
    /// 0…1
    public var grandMaster: Double
    public var blackout: Bool

    public init(patch: Patch = Patch(), snapshots: [UUID: Snapshot] = [:], playbacks: [PlaybackState] = [],
                programmer: Programmer = Programmer(), grandMaster: Double = 1, blackout: Bool = false) {
        self.patch = patch; self.snapshots = snapshots; self.playbacks = playbacks
        self.programmer = programmer; self.grandMaster = grandMaster; self.blackout = blackout
    }
}
