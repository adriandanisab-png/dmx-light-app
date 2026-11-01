import Foundation

/// Live, uncommitted edits. Overrides playback until cleared.
public struct Programmer: Equatable, Sendable {
    /// Ordered; selection order matters for effects later.
    public var selection: [UUID]
    /// Only "touched" channels.
    public private(set) var values: [UUID: FixtureValues]

    public init(selection: [UUID] = []) {
        self.selection = selection
        self.values = [:]
    }

    public var isEmpty: Bool { values.isEmpty }

    public mutating func set(channel: Int, to value: UInt8, for fixtureIDs: [UUID]) {
        for id in fixtureIDs { values[id, default: [:]][channel] = value }
    }

    /// Runs `edit` on every selected fixture with that fixture's own type.
    public mutating func apply(_ edit: (FixtureType, inout FixtureValues) -> Void, patch: Patch) {
        for id in selection {
            guard let fixture = patch.fixtures.first(where: { $0.id == id }),
                  let type = patch.type(of: fixture) else { continue }
            var v = values[id] ?? [:]
            edit(type, &v)
            if !v.isEmpty { values[id] = v }
        }
    }

    public mutating func clear() {
        selection = []
        values = [:]
    }

    public func record(name: String, colorHex: String) -> Snapshot {
        Snapshot(name: name, colorHex: colorHex, values: values.filter { !$0.value.isEmpty })
    }
}
