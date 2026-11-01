import Foundation

/// Position on the stage, 0…1 in both axes.
public struct StagePoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct Fixture: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var typeID: UUID
    /// 1…512, first channel.
    public var address: Int
    /// 1…12.
    public var consoleScanner: Int?
    public var stagePosition: StagePoint?
    public init(id: UUID = UUID(), name: String, typeID: UUID, address: Int,
                consoleScanner: Int? = nil, stagePosition: StagePoint? = nil) {
        self.id = id; self.name = name; self.typeID = typeID; self.address = address
        self.consoleScanner = consoleScanner; self.stagePosition = stagePosition
    }
}
