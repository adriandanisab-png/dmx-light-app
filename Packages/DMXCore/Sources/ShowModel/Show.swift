import Foundation

public enum ShowFileError: Error, Equatable { case corrupt, newerVersion(Int) }

public struct Show: Codable, Equatable, Sendable {
    public static let currentFormatVersion = 1
    public var formatVersion: Int
    public var patch: Patch
    public var console: ConsoleMap

    public init() {
        formatVersion = Self.currentFormatVersion
        patch = Patch()
        console = ConsoleMap()
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
