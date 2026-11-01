import Foundation
import ShowModel

@MainActor
public final class ConsoleController: ObservableObject {
    @Published public private(set) var state = ConsoleState()
    @Published public var isArmed = false
    @Published public var map: ConsoleMap
    public private(set) var sender: MIDISender

    public init(sender: MIDISender, map: ConsoleMap) {
        self.sender = sender
        self.map = map
    }

    /// Swap the output (e.g. when the user picks another MIDI interface).
    public func setSender(_ sender: MIDISender) { self.sender = sender }

    public func fire(_ target: ConsoleTarget) async throws {
        let note = try target.noteNumber()          // rejects unreachable targets first
        try await sendNote(note: note, velocity: 127, channel: map.midiChannel)
        state.applyToggle(target)                    // only after the Note On succeeded
        await sendNoteOffIfConfigured(note: note, channel: map.midiChannel)
    }

    public func recall(_ look: ConsoleLook) async throws {
        let targets = look.targets.subtracting([.blackout])
        // Validate everything up front so a bad look sends nothing.
        for t in targets { _ = try t.noteNumber() }
        for t in state.toggles(toReach: targets) { try await fire(t) }
    }

    public func toggleBlackout() async throws { try await fire(.blackout) }

    /// MIDI test panel. Still requires arming; does not change believed state.
    public func sendRaw(note: UInt8, velocity: UInt8, channel: Int) async throws {
        try await sendNote(note: note, velocity: velocity, channel: channel)
        await sendNoteOffIfConfigured(note: note, channel: channel)
    }

    public func markAllOff() { state.reset() }

    private func sendNote(note: UInt8, velocity: UInt8, channel: Int) async throws {
        guard isArmed else { throw ConsoleError.notArmed }
        let message = try MIDIMessage.noteOn(channel: channel, note: note, velocity: velocity)
        guard sender.isConnected else { throw ConsoleError.noDestination }
        do { try sender.send(message) }
        catch let e as ConsoleError { throw e }
        catch { throw ConsoleError.sendFailed(String(describing: error)) }
    }

    /// A failed Note Off is deliberately ignored: the console already toggled on Note On.
    private func sendNoteOffIfConfigured(note: UInt8, channel: Int) async {
        guard let ms = map.noteOffDelayMs else { return }
        if ms > 0 { try? await Task.sleep(for: .milliseconds(ms)) }
        if let off = try? MIDIMessage.noteOff(channel: channel, note: note) { try? sender.send(off) }
    }
}
