import Foundation

/// Live, uncommitted edits. Overrides playback until cleared.
public struct Programmer: Equatable, Sendable {
    /// Ordered; selection order matters for effects later.
    public var selection: [UUID]
    /// Only "touched" channels.
    public private(set) var values: [UUID: FixtureValues]
    /// Fixtures with no intensity channel: the programmer's dimmer level and the unscaled colour it scales.
    public private(set) var virtualDimmer: [UUID: Double] = [:]
    private var colourBase: [UUID: FixtureValues] = [:]

    private static let colourFunctions: Set<ChannelFunction> = [.red, .green, .blue, .white, .amber, .uv]

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
        virtualDimmer = [:]
        colourBase = [:]
    }

    /// Intensity for every selected fixture. Fixtures without an intensity channel get a virtual dimmer
    /// that scales their colour: the programmer's colour, else what `rendered` says is on stage, else white.
    public mutating func applyIntensity(_ level: Double, patch: Patch, rendered: (Fixture, Int) -> UInt8) {
        let level = min(max(level, 0), 1)
        for (fixture, type) in selectedFixtures(patch) {
            if type.channels.contains(where: { $0.function == .intensity }) {
                Attributes.setIntensity(level, type: type, into: &values[fixture.id, default: [:]])
                continue
            }
            var base = colourBase[fixture.id] ?? [:]
            if base.isEmpty {
                for (i, ch) in type.channels.enumerated() where Self.colourFunctions.contains(ch.function) {
                    base[i] = rendered(fixture, i)
                }
                if base.values.allSatisfy({ $0 == 0 }) {
                    base = [:]
                    Attributes.setColor(RGB(r: 1, g: 1, b: 1), type: type, into: &base)
                }
            }
            guard !base.isEmpty else { continue }
            colourBase[fixture.id] = base
            virtualDimmer[fixture.id] = level
            writeScaled(base, level: level, for: fixture.id)
        }
    }

    /// Colour for every selected fixture, keeping any virtual dimmer level already set.
    public mutating func applyColor(_ c: RGB, patch: Patch) {
        for (fixture, type) in selectedFixtures(patch) {
            var base: FixtureValues = [:]
            Attributes.setColor(c, type: type, into: &base)
            guard !base.isEmpty else { continue }
            if type.channels.contains(where: { $0.function == .intensity }) {
                values[fixture.id, default: [:]].merge(base) { _, new in new }
            } else {
                colourBase[fixture.id] = base
                writeScaled(base, level: virtualDimmer[fixture.id] ?? 1, for: fixture.id)
            }
        }
    }

    /// Sets the channel matching `channel` (same name, else same function unless generic) on every
    /// selected fixture whose type has one, so a fader moves mixed fixture types together.
    public mutating func setMatching(_ channel: ChannelDef, to value: UInt8, patch: Patch) {
        for (fixture, type) in selectedFixtures(patch) {
            let byName = type.channels.firstIndex { $0.name.caseInsensitiveCompare(channel.name) == .orderedSame }
            let byFunction = channel.function == .generic ? nil : type.channels.firstIndex { $0.function == channel.function }
            guard let i = byName ?? byFunction else { continue }
            values[fixture.id, default: [:]][i] = value
        }
    }

    private func selectedFixtures(_ patch: Patch) -> [(Fixture, FixtureType)] {
        selection.compactMap { id in
            guard let f = patch.fixtures.first(where: { $0.id == id }), let t = patch.type(of: f) else { return nil }
            return (f, t)
        }
    }

    private mutating func writeScaled(_ base: FixtureValues, level: Double, for id: UUID) {
        for (i, v) in base { values[id, default: [:]][i] = UInt8((Double(v) * level).rounded()) }
    }

    public func record(name: String, colorHex: String) -> Snapshot {
        Snapshot(name: name, colorHex: colorHex, values: values.filter { !$0.value.isEmpty })
    }
}
