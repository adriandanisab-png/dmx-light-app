import ShowModel

public enum MIDIMessageError: Error, Equatable {
    case zeroVelocity       // Note On with velocity 0 means Note Off on the wire; never send it.
    case valueOutOfRange(Int)
}

public struct MIDIMessage: Equatable, Sendable {
    public let bytes: [UInt8]

    private static func validate(channel: Int, note: UInt8) throws {
        guard (1...16).contains(channel) else { throw ConsoleError.midiChannelOutOfRange(channel) }
        guard note <= 127 else { throw MIDIMessageError.valueOutOfRange(Int(note)) }
    }

    public static func noteOn(channel: Int, note: UInt8, velocity: UInt8 = 127) throws -> MIDIMessage {
        try validate(channel: channel, note: note)
        guard velocity > 0 else { throw MIDIMessageError.zeroVelocity }
        guard velocity <= 127 else { throw MIDIMessageError.valueOutOfRange(Int(velocity)) }
        return MIDIMessage(bytes: [0x90 | UInt8(channel - 1), note, velocity])
    }

    public static func noteOff(channel: Int, note: UInt8) throws -> MIDIMessage {
        try validate(channel: channel, note: note)
        return MIDIMessage(bytes: [0x80 | UInt8(channel - 1), note, 0])
    }
}
