import Foundation

public enum ShowFileError: Error, Equatable { case corrupt, newerVersion(Int) }

public struct Show: Codable, Equatable, Sendable {
    public static let currentFormatVersion = 1
    public var formatVersion: Int
    public var patch: Patch
    public var console: ConsoleMap
    public var snapshots: [Snapshot]
    public var stage: StagePlot
    public var effects: [Effect]
    public var cueLists: [CueList]

    public init() {
        formatVersion = Self.currentFormatVersion
        patch = Patch()
        console = ConsoleMap()
        snapshots = []
        stage = StagePlot()
        effects = []
        cueLists = []
    }

    // Additions since Plan 1 decode with defaults so older files still open.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try c.decode(Int.self, forKey: .formatVersion)
        patch = try c.decode(Patch.self, forKey: .patch)
        console = try c.decode(ConsoleMap.self, forKey: .console)
        snapshots = try c.decodeIfPresent([Snapshot].self, forKey: .snapshots) ?? []
        stage = try c.decodeIfPresent(StagePlot.self, forKey: .stage) ?? StagePlot()
        effects = try c.decodeIfPresent([Effect].self, forKey: .effects) ?? []
        cueLists = try c.decodeIfPresent([CueList].self, forKey: .cueLists) ?? []
    }

    private struct VersionProbe: Decodable { var formatVersion: Int }

    public static func decode(_ data: Data) throws -> Show {
        let decoder = JSONDecoder()
        // Check the version first so a newer file reports newerVersion even if its shape changed.
        guard let probe = try? decoder.decode(VersionProbe.self, from: data) else { throw ShowFileError.corrupt }
        if probe.formatVersion > currentFormatVersion { throw ShowFileError.newerVersion(probe.formatVersion) }
        guard probe.formatVersion >= 1, let show = try? decoder.decode(Show.self, from: data) else {
            throw ShowFileError.corrupt
        }
        return show
    }

    public func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
