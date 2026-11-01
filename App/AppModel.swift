import SwiftUI
import Combine
import ShowModel
import DMXOutput
import ConsoleMIDI

/// Per-window runtime state: the DMX frame, the output gate, and the console controller.
/// One instance per document window (owned by the root view as a `@StateObject`).
@MainActor
final class AppModel: ObservableObject {
    static let destinationDefaultsKey = "midiDestinationUniqueID"
    static let recordingMIDIArgument = "-useRecordingMIDI"

    @Published var frame = DMXFrame()
    @Published var toast: String?
    @Published private(set) var destinations: [MIDIDestinationInfo] = []
    @Published private(set) var selectedDestinationID: Int32?
    @Published private(set) var midiLog: [String] = []

    let virtualOutput: VirtualDMXOutput
    let gate: OutputGate
    let console: ConsoleController

    /// UI tests inject a connected `RecordingMIDISender` with the `-useRecordingMIDI` launch argument.
    private let usesRecordingMIDI: Bool
    private var toastTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    var isArmed: Bool { gate.isArmed }
    var outputStatus: String { "Virtual output \u{2014} preview only" }

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        usesRecordingMIDI = arguments.contains(Self.recordingMIDIArgument)
        virtualOutput = VirtualDMXOutput()
        gate = OutputGate(device: virtualOutput)
        let sender: MIDISender = usesRecordingMIDI ? RecordingMIDISender() : Self.disconnectedSender()
        console = ConsoleController(sender: sender, map: ConsoleMap())
        // Re-publish nested changes so views observing the model refresh.
        gate.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        console.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)

        refreshDestinations()
        if !usesRecordingMIDI, let saved = UserDefaults.standard.object(forKey: Self.destinationDefaultsKey) as? Int,
           let id = Int32(exactly: saved) {
            selectDestination(id)
        }
    }

    private static func disconnectedSender() -> RecordingMIDISender {
        let s = RecordingMIDISender()
        s.isConnected = false
        return s
    }

    // MARK: Show loading

    /// Called when the window's document appears or its console map changes.
    func loadConsoleMap(_ map: ConsoleMap) {
        if console.map != map { console.map = map }
    }

    func loadPatch(_ patch: Patch) {
        frame = PatchWriter.defaults(for: patch)
    }

    /// Newly added fixtures start at their channel defaults; existing values are kept.
    func patchDidChange(from old: Patch, to new: Patch) {
        let known = Set(old.fixtures.map(\.id))
        for fixture in new.fixtures where !known.contains(fixture.id) {
            guard let type = new.type(of: fixture) else { continue }
            for (i, ch) in type.channels.enumerated() { frame[fixture.address + i] = ch.defaultValue }
        }
    }

    // MARK: Arming and DMX

    func setArmed(_ on: Bool) {
        if on { gate.arm() } else { gate.disarm() }
        console.isArmed = on
    }

    func setChannel(_ value: UInt8, index: Int, of fixture: Fixture, patch: Patch) {
        PatchWriter.set(value, channel: index, of: fixture, in: &frame, patch: patch)
        do { _ = try gate.submit(frame) } catch { showToast(Self.describe(error)) }
    }

    // MARK: MIDI destination

    func refreshDestinations() {
        destinations = CoreMIDISender.destinations()
    }

    func selectDestination(_ id: Int32?) {
        selectedDestinationID = id
        guard !usesRecordingMIDI else { return }
        if let id {
            UserDefaults.standard.set(Int(id), forKey: Self.destinationDefaultsKey)
            do { console.setSender(try CoreMIDISender(destinationUniqueID: id)) }
            catch {
                console.setSender(Self.disconnectedSender())
                showToast(Self.describe(error))
            }
        } else {
            UserDefaults.standard.removeObject(forKey: Self.destinationDefaultsKey)
            console.setSender(Self.disconnectedSender())
        }
    }

    // MARK: Console actions (errors become toasts)

    func fire(_ target: ConsoleTarget) async {
        do { try await console.fire(target) } catch { showToast(Self.describe(error)) }
    }

    func recall(_ look: ConsoleLook) async {
        do { try await console.recall(look) } catch { showToast(Self.describe(error)) }
    }

    func sendRaw(note: Int, velocity: Int, channel: Int) async {
        let label = "ch \(channel) note \(note) vel \(velocity)"
        do {
            guard (0...127).contains(note), (0...127).contains(velocity) else {
                throw MIDIMessageError.valueOutOfRange((0...127).contains(note) ? velocity : note)
            }
            try await console.sendRaw(note: UInt8(note), velocity: UInt8(velocity), channel: channel)
            midiLog.append("sent \(label)")
        } catch {
            midiLog.append("failed \(label): \(Self.describe(error))")
            showToast(Self.describe(error))
        }
        if midiLog.count > 200 { midiLog.removeFirst(midiLog.count - 200) }
    }

    func clearLog() { midiLog = [] }

    // MARK: Toast

    func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    static func describe(_ error: Error) -> String {
        switch error {
        case ConsoleError.notArmed: return "Output not armed"
        case ConsoleError.noDestination: return "MIDI interface not connected: nothing sent"
        case let ConsoleError.sendFailed(detail): return "MIDI send failed (\(detail)): nothing changed"
        case let ConsoleError.bankNotReachable(b): return "Bank \(b) can't be reached over MIDI (banks 1\u{2013}15 only)"
        case let ConsoleError.sceneOutOfRange(s): return "Scene \(s) is out of range (1\u{2013}8)"
        case let ConsoleError.chaseOutOfRange(c): return "Chase \(c) is out of range (1\u{2013}6)"
        case let ConsoleError.midiChannelOutOfRange(c): return "MIDI channel \(c) is out of range (1\u{2013}16)"
        case MIDIMessageError.zeroVelocity: return "Velocity 0 is never sent (it would mean Note Off)"
        case let MIDIMessageError.valueOutOfRange(v): return "Value \(v) is out of range (0\u{2013}127)"
        default: return String(describing: error)
        }
    }
}
