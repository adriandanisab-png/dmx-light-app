import Testing
import ShowModel
@testable import ConsoleMIDI

@Test func noteOnBytes() throws {
    #expect(try MIDIMessage.noteOn(channel: 1, note: 0).bytes == [0x90, 0, 127])
    #expect(try MIDIMessage.noteOn(channel: 16, note: 5).bytes[0] == 0x9F)
    #expect(throws: MIDIMessageError.zeroVelocity) { try MIDIMessage.noteOn(channel: 1, note: 0, velocity: 0) }
    #expect(throws: ConsoleError.midiChannelOutOfRange(17)) { try MIDIMessage.noteOn(channel: 17, note: 0) }
    #expect(try MIDIMessage.noteOff(channel: 3, note: 8).bytes == [0x82, 8, 0])
}
