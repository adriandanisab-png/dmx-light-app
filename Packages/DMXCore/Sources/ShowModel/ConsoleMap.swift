import Foundation

public struct ConsoleCell: Codable, Hashable, Sendable {
    public var name: String
    public var colorHex: String
    public var notes: String
    public init(name: String = "", colorHex: String = "#808080", notes: String = "") {
        self.name = name; self.colorHex = colorHex; self.notes = notes
    }
}

public struct ConsoleLook: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    /// Blackout is not allowed here.
    public var targets: Set<ConsoleTarget>
    public init(id: UUID = UUID(), name: String, targets: Set<ConsoleTarget>) {
        self.id = id; self.name = name; self.targets = targets
    }
}

public struct ConsoleMap: Codable, Equatable, Sendable {
    /// 1…16.
    public var midiChannel: Int
    /// nil = never send Note Off.
    public var noteOffDelayMs: Int?
    public var cells: [ConsoleTarget: ConsoleCell]
    public var looks: [ConsoleLook]

    public init(midiChannel: Int = 1, noteOffDelayMs: Int? = 50,
                cells: [ConsoleTarget: ConsoleCell] = [:], looks: [ConsoleLook] = []) {
        self.midiChannel = midiChannel; self.noteOffDelayMs = noteOffDelayMs
        self.cells = cells; self.looks = looks
    }

    public func validate() -> [ConsoleError] {
        var errors: [ConsoleError] = []
        if !(1...16).contains(midiChannel) { errors.append(.midiChannelOutOfRange(midiChannel)) }
        func check(_ t: ConsoleTarget) {
            do { _ = try t.noteNumber() } catch let e as ConsoleError { errors.append(e) } catch {}
        }
        for t in cells.keys.sorted() { check(t) }
        for look in looks { for t in look.targets.sorted() { check(t) } }
        return errors
    }

    // Dictionaries keyed by a non-String Codable type encode as flat arrays;
    // store as a sorted array of pairs for stable, readable JSON instead.
    private struct CellEntry: Codable { var target: ConsoleTarget; var cell: ConsoleCell }
    enum CodingKeys: String, CodingKey { case midiChannel, noteOffDelayMs, cells, looks }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        midiChannel = try c.decode(Int.self, forKey: .midiChannel)
        noteOffDelayMs = try c.decodeIfPresent(Int.self, forKey: .noteOffDelayMs)
        let entries = try c.decode([CellEntry].self, forKey: .cells)
        cells = Dictionary(entries.map { ($0.target, $0.cell) }, uniquingKeysWith: { $1 })
        looks = try c.decode([ConsoleLook].self, forKey: .looks)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(midiChannel, forKey: .midiChannel)
        try c.encodeIfPresent(noteOffDelayMs, forKey: .noteOffDelayMs)
        try c.encode(cells.keys.sorted().map { CellEntry(target: $0, cell: cells[$0]!) }, forKey: .cells)
        try c.encode(looks, forKey: .looks)
    }
}
