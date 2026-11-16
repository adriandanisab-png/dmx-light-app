import SwiftUI
import Combine
import ShowModel
import DMXOutput
import Engine
import Effects
import ConsoleMIDI

/// Where DMX goes. Stored per Mac in UserDefaults, not in the show.
enum OutputMode: String, Codable, CaseIterable, Identifiable {
    case previewOnly, directOpenDMX, consoleMIDI
    var id: String { rawValue }
    var title: String {
        switch self {
        case .previewOnly: return "Preview only"
        case .directOpenDMX: return "Direct (Open DMX)"
        case .consoleMIDI: return "Console (MIDI)"
        }
    }
}

/// Per-window runtime state: the engine, the output device, the programmer and the console controller.
/// One instance per document window (owned by the root view as a `@StateObject`).
@MainActor
final class AppModel: ObservableObject {
    static let destinationDefaultsKey = "midiDestinationUniqueID"
    static let recordingMIDIArgument = "-useRecordingMIDI"
    static let outputModeKey = "outputMode"
    static let portPathKey = "dmxPortPath"
    static let refreshHzKey = "dmxRefreshHz"

    @Published var toast: String?
    @Published private(set) var destinations: [MIDIDestinationInfo] = []
    @Published private(set) var selectedDestinationID: Int32?
    @Published private(set) var midiLog: [String] = []

    @Published private(set) var outputMode: OutputMode
    @Published private(set) var portPath: String?
    @Published private(set) var refreshHz: Double
    @Published private(set) var isArmed = false
    @Published var showAdapterLost = false
    @Published private(set) var programmer = Programmer()
    @Published private(set) var activeSnapshots: [UUID] = []
    /// Snapshot fader positions of the active snapshots (a missing entry means 1).
    @Published private(set) var snapshotLevels: [UUID: Double] = [:]
    /// Fixture faders (HTP live layer). Fixtures at 0 are not stored.
    @Published private(set) var fixtureLevels: [UUID: Double] = [:]
    @Published var grandMaster: Double = 1 {
        didSet { let v = grandMaster; runner.update { $0.grandMaster = v } }
    }
    @Published var blackout = false {
        didSet { let v = blackout; runner.update { $0.blackout = v } }
    }

    @Published private(set) var runningEffects: [RunningEffect] = []
    /// Fixtures picked on the Playback page for preset effects, in pick order (= chase order). Empty = all.
    @Published var effectTargets: [UUID] = []
    @Published private(set) var bpm: Double = 120
    @Published private(set) var activeCueListID: UUID?
    @Published private(set) var cueCurrent: Cue?

    let runner: EngineRunner
    let console: ConsoleController
    private var patch = Patch()
    private var snapshots: [UUID: Snapshot] = [:]
    private var directDevice: OpenDMXOutput?
    private var show = Show()
    private var effects: [UUID: Effect] = [:]
    private var tapTempo = TapTempo()
    private var previewEffect: Effect?
    private var previewStartedAt: TimeInterval = 0
    private var player: CueListPlayer?
    private var cueStartedAt: TimeInterval = 0
    private var followArmed = false
    private var followTask: Task<Void, Never>?

    /// UI tests inject a connected `RecordingMIDISender` with the `-useRecordingMIDI` launch argument.
    private let usesRecordingMIDI: Bool
    private var toastTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        usesRecordingMIDI = arguments.contains(Self.recordingMIDIArgument)
        let defaults = UserDefaults.standard
        outputMode = defaults.string(forKey: Self.outputModeKey).flatMap(OutputMode.init(rawValue:)) ?? .previewOnly
        portPath = defaults.string(forKey: Self.portPathKey)
        let hz = defaults.double(forKey: Self.refreshHzKey)
        refreshHz = hz == 0 ? 30 : min(max(hz, OpenDMXOutput.refreshRange.lowerBound), OpenDMXOutput.refreshRange.upperBound)
        runner = EngineRunner()
        let sender: MIDISender = usesRecordingMIDI ? RecordingMIDISender() : Self.disconnectedSender()
        console = ConsoleController(sender: sender, map: ConsoleMap())
        // Re-publish nested changes so views observing the model refresh.
        console.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        runner.onOutputError = { [weak self] error in
            Task { @MainActor in self?.showToast("DMX output failed: \(error)") }
        }

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

    /// Starts the engine tick (idempotent) when the window opens.
    func start() { runner.start() }

    /// Pushes the patch and snapshots from the document into the engine.
    func loadShow(_ show: Show) {
        self.show = show
        loadConsoleMap(show.console)
        patch = show.patch
        snapshots = Dictionary(show.snapshots.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let p = show.patch, s = snapshots
        runner.update { $0.patch = p; $0.snapshots = s }
        // Drop references to fixtures/snapshots that no longer exist.
        let known = Set(show.patch.fixtures.map(\.id))
        if programmer.selection.contains(where: { !known.contains($0) }) {
            programmer.selection.removeAll { !known.contains($0) }
            pushProgrammer()
        }
        if fixtureLevels.keys.contains(where: { !known.contains($0) }) {
            fixtureLevels = fixtureLevels.filter { known.contains($0.key) }
            pushFixtureLevels()
        }
        let stillActive = activeSnapshots.filter { s[$0] != nil }
        if stillActive != activeSnapshots {
            activeSnapshots = stillActive
            snapshotLevels = snapshotLevels.filter { s[$0.key] != nil }
            runner.update { input in input.playbacks.removeAll { s[$0.snapshotID] == nil } }
        }
        effects = Dictionary(show.effects.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        runningEffects.removeAll { effects[$0.effectID] == nil }
        pushEffects()
        if activeCueListID != nil { rebuildPlayer() }
    }

    // MARK: Programmer

    private func pushProgrammer() {
        let p = programmer
        runner.update { $0.programmer = p }
    }

    func setSelection(_ ids: [UUID]) {
        programmer.selection = ids
        pushProgrammer()
    }

    func programmerApply(_ edit: (FixtureType, inout FixtureValues) -> Void) {
        programmer.apply(edit, patch: patch)
        pushProgrammer()
    }

    func programmerIntensity(_ level: Double) {
        let frame = runner.latestFrame()
        programmer.applyIntensity(level, patch: patch) { f, ch in frame[f.address + ch] }
        pushProgrammer()
    }

    func programmerColor(_ c: RGB) {
        programmer.applyColor(c, patch: patch)
        pushProgrammer()
    }

    /// Moves the matching channel on every selected fixture, whatever its type.
    func programmerSetMatching(_ channel: ChannelDef, to value: UInt8) {
        programmer.setMatching(channel, to: value, patch: patch)
        pushProgrammer()
    }

    func programmerSet(channel: Int, to value: UInt8, fixtures ids: [UUID]) {
        programmer.set(channel: channel, to: value, for: ids)
        pushProgrammer()
    }

    func clearProgrammer() {
        programmer.clear()
        pushProgrammer()
    }

    /// Value to show for a channel in a fader: the programmer's value, else what is currently rendered.
    func shownValue(fixture: Fixture, channel: Int) -> UInt8 {
        programmer.values[fixture.id]?[channel] ?? runner.latestFrame()[fixture.address + channel]
    }

    // MARK: Playback

    /// Recalls a snapshot. Not layered = replaces all playbacks; layered = adds, or removes if already on.
    /// The fade starts from what was on screen without grand master, blackout and programmer, so an
    /// interrupted fade continues from the current value.
    func recall(_ snapshotID: UUID, layered: Bool, fade: Double?) {
        guard let snap = snapshots[snapshotID] else { return }
        if layered, activeSnapshots.contains(snapshotID) { release(snapshotID); return }
        var input = runner.currentInput()
        let now = runner.now()
        input.grandMaster = 1; input.blackout = false; input.programmer = Programmer(); input.runningEffects = []
        input.fixtureLevels = [:]
        let from = Engine.render(input, at: now)
        let pb = PlaybackState(snapshotID: snapshotID, startedAt: now,
                               fade: max(fade ?? snap.defaultFade, 0), fadeFrom: from)
        if layered {
            activeSnapshots.append(snapshotID)
            snapshotLevels[snapshotID] = 1
            runner.update { $0.playbacks.append(pb) }
        } else {
            activeSnapshots = [snapshotID]
            snapshotLevels = [snapshotID: 1]
            runner.update { $0.playbacks = [pb] }
        }
    }

    /// Fader position of a snapshot: 0 when it is not active.
    func snapshotLevel(_ id: UUID) -> Double {
        activeSnapshots.contains(id) ? snapshotLevels[id] ?? 1 : 0
    }

    /// Snapshot fader. Raising from 0 activates the snapshot layered, without a fade; 0 releases it.
    func setSnapshotLevel(_ id: UUID, _ level: Double) {
        let l = min(max(level, 0), 1)
        if l <= 0 { release(id); return }
        if !activeSnapshots.contains(id) {
            guard snapshots[id] != nil else { return }
            recall(id, layered: true, fade: 0)
        }
        snapshotLevels[id] = l
        runner.update { input in
            if let i = input.playbacks.firstIndex(where: { $0.snapshotID == id }) { input.playbacks[i].level = l }
        }
    }

    // MARK: Fixture faders

    private func pushFixtureLevels() {
        let levels = fixtureLevels
        runner.update { $0.fixtureLevels = levels }
    }

    func setFixtureLevel(_ id: UUID, _ level: Double) {
        let l = min(max(level, 0), 1)
        if l <= 0 { fixtureLevels[id] = nil } else { fixtureLevels[id] = l }
        pushFixtureLevels()
    }

    func clearFixtureFaders() {
        fixtureLevels = [:]
        pushFixtureLevels()
    }

    func release(_ snapshotID: UUID) {
        activeSnapshots.removeAll { $0 == snapshotID }
        snapshotLevels[snapshotID] = nil
        runner.update { input in input.playbacks.removeAll { $0.snapshotID == snapshotID } }
    }

    // MARK: Effects

    /// Engine input = saved effects + the editor's live preview (if any).
    private func pushEffects() {
        var fx = effects
        var run = runningEffects
        if let p = previewEffect {
            fx[p.id] = p
            if !run.contains(where: { $0.effectID == p.id }) {
                run.append(RunningEffect(effectID: p.id, startedAt: previewStartedAt, level: 1))
            }
        }
        let b = bpm, effectsNow = fx, runNow = run
        runner.update { $0.effects = effectsNow; $0.runningEffects = runNow; $0.bpm = b }
    }

    func isRunning(_ id: UUID) -> Bool { runningEffects.contains { $0.effectID == id } }

    func effectLevel(_ id: UUID) -> Double { runningEffects.first { $0.effectID == id }?.level ?? 0 }

    /// Starts (or re-levels) an effect. Chases are exclusive: starting one stops the other chases.
    func startEffect(_ effect: Effect, level: Double = 1) {
        effects[effect.id] = effect
        if !effect.overlay {
            runningEffects.removeAll { $0.effectID != effect.id && effects[$0.effectID]?.overlay == false }
        }
        let l = min(max(level, 0), 1)
        if let i = runningEffects.firstIndex(where: { $0.effectID == effect.id }) {
            runningEffects[i].level = l
        } else {
            runningEffects.append(RunningEffect(effectID: effect.id, startedAt: runner.now(), level: l))
        }
        pushEffects()
    }

    func stopEffect(_ id: UUID) {
        runningEffects.removeAll { $0.effectID == id }
        pushEffects()
    }

    func toggleEffect(_ effect: Effect) {
        if isRunning(effect.id) { stopEffect(effect.id) } else { startEffect(effect) }
    }

    /// Re-targets a running or saved effect to new fixtures without restarting it.
    func retarget(_ effect: Effect, to ids: [UUID]) -> Effect {
        var e = effect
        e.fixtureIDs = ids
        if isRunning(e.id) { startEffect(e, level: effectLevel(e.id)) }
        return e
    }

    func setEffectLevel(_ id: UUID, _ level: Double) {
        guard let i = runningEffects.firstIndex(where: { $0.effectID == id }) else { return }
        runningEffects[i].level = min(max(level, 0), 1)
        pushEffects()
    }

    /// Effect fader: raising a stopped saved effect starts it at that level; 0 stops it.
    func setEffectFader(_ id: UUID, _ level: Double) {
        let l = min(max(level, 0), 1)
        if l <= 0 { stopEffect(id); return }
        if isRunning(id) { setEffectLevel(id, l) }
        else if let e = effects[id] { startEffect(e, level: l) }
    }

    /// The effect editor shows its draft live on the stage; nil ends the preview.
    func setPreview(_ effect: Effect?) {
        if effect != nil, previewEffect == nil { previewStartedAt = runner.now() }
        previewEffect = effect
        pushEffects()
    }

    func tapTempoTap() {
        tapTempo.tap(at: runner.now())
        bpm = tapTempo.bpm
        pushEffects()
    }

    func setBPM(_ value: Double) {
        tapTempo.set(bpm: value)
        bpm = tapTempo.bpm
        pushEffects()
    }

    // MARK: Cue lists

    var cueMode: CueMode { outputMode == .consoleMIDI ? .console : .direct }

    var activeCueList: CueList? { show.cueLists.first { $0.id == activeCueListID } }

    /// The cue after the current one (the first cue when nothing has played; wraps when the list loops).
    var cueNext: Cue? {
        guard let list = activeCueList else { return nil }
        let cues = list.cues.sorted { $0.number < $1.number }
        guard let cur = cueCurrent else { return cues.first }
        return cues.first { $0.number > cur.number } ?? (list.loops ? cues.first : nil)
    }

    func selectCueList(_ id: UUID?) {
        followArmed = false
        cueCurrent = nil
        guard let id, let list = show.cueLists.first(where: { $0.id == id }) else {
            activeCueListID = nil; player = nil; followTask?.cancel(); followTask = nil
            return
        }
        activeCueListID = id
        player = CueListPlayer(list: list, show: show)
        startFollowTimer()
    }

    /// The list or show changed: rebuild the player but stay on the current cue without replaying it.
    private func rebuildPlayer() {
        guard let list = activeCueList else { selectCueList(nil); return }
        var p = CueListPlayer(list: list, show: show)
        if let n = cueCurrent?.number { _ = p.jump(to: n, mode: cueMode) }
        player = p
        cueCurrent = p.currentCue
    }

    func go() { run { $0.go(mode: cueMode) } }
    func back() { run { $0.back(mode: cueMode) } }

    private func run(_ step: (inout CueListPlayer) -> [CueAction]) {
        guard var p = player else { showToast("Pick a cue list first"); return }
        let actions = step(&p)
        player = p
        cueCurrent = p.currentCue
        var notes: [String] = []
        var played = false
        for action in actions {
            switch action {
            case let .playDirect(cue): playDirect(cue); played = true
            case let .playConsole(cue): playConsole(cue); played = true
            case let .skipped(cue, reason): notes.append("Skipped cue \(Self.numberText(cue.number)): \(reason)")
            case .end: notes.append(p.currentCue == nil ? "No cue for this mode" : "End of cue list")
            }
        }
        followArmed = played
        if played { cueStartedAt = runner.now() }
        if !notes.isEmpty { showToast(notes.joined(separator: ". ")) }
    }

    static func numberText(_ n: Double) -> String { String(format: "%g", n) }

    /// Replaces the playbacks with the cue's snapshots (fading over `cue.fade`) and its effects.
    private func playDirect(_ cue: Cue) {
        let part = cue.direct ?? DirectCuePart()
        let ids = part.snapshotIDs.filter { snapshots[$0] != nil }
        var input = runner.currentInput()
        let now = runner.now()
        input.grandMaster = 1; input.blackout = false; input.programmer = Programmer(); input.runningEffects = []
        input.fixtureLevels = [:]
        let from = Engine.render(input, at: now)
        let pbs = ids.map { PlaybackState(snapshotID: $0, startedAt: now, fade: max(cue.fade, 0), fadeFrom: from) }
        activeSnapshots = ids
        snapshotLevels = Dictionary(ids.map { ($0, 1.0) }, uniquingKeysWith: { a, _ in a })
        runner.update { $0.playbacks = pbs }
        let old = runningEffects
        runningEffects = part.effectIDs.filter { effects[$0] != nil }.map { id in
            old.first { $0.effectID == id } ?? RunningEffect(effectID: id, startedAt: now, level: 1)
        }
        pushEffects()
    }

    private func playConsole(_ cue: Cue) {
        let look: ConsoleLook
        switch cue.console {
        case let .look(id)?:
            guard let l = console.map.looks.first(where: { $0.id == id }) else { return }
            look = l
        case let .targets(set)?: look = ConsoleLook(id: UUID(), name: "", targets: set)
        case nil: return
        }
        Task { await recall(look) }
    }

    /// 20 Hz main-actor timer for auto-follow cues.
    private func startFollowTimer() {
        followTask?.cancel()
        followTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                self?.followTick()
            }
        }
    }

    private func followTick() {
        guard followArmed, let p = player, p.nextAutoFollow(at: runner.now(), cueStartedAt: cueStartedAt) else { return }
        followArmed = false
        go()
    }

    // MARK: Output mode and arming

    func setOutputMode(_ mode: OutputMode) {
        guard !isArmed else { return }
        outputMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.outputModeKey)
    }

    func setPort(_ path: String?) {
        guard !isArmed else { return }
        portPath = path
        if let path { UserDefaults.standard.set(path, forKey: Self.portPathKey) }
        else { UserDefaults.standard.removeObject(forKey: Self.portPathKey) }
    }

    func setRefreshHz(_ hz: Double) {
        guard !isArmed else { return }
        refreshHz = min(max(hz, OpenDMXOutput.refreshRange.lowerBound), OpenDMXOutput.refreshRange.upperBound)
        UserDefaults.standard.set(refreshHz, forKey: Self.refreshHzKey)
    }

    /// One ARM for the window: DMX (engine output) and MIDI (console). The Open DMX port is only
    /// opened while armed, so nothing at all goes on the line when disarmed.
    func setArmed(_ on: Bool) {
        if on {
            if outputMode == .directOpenDMX {
                guard let path = portPath else { showToast("Pick a DMX adapter in Devices first"); return }
                let device = OpenDMXOutput(path: path, refreshHz: refreshHz)
                device.onDisconnect = { [weak self] in
                    Task { @MainActor in if self?.isArmed == true { self?.showAdapterLost = true } }
                }
                do { try device.start() } catch {
                    showToast("Can't open \(path): \(error)")
                    return
                }
                directDevice = device
                runner.output = device
            } else {
                runner.output = nil
            }
            runner.outputEnabled = true
            isArmed = true
        } else {
            runner.outputEnabled = false
            runner.output = nil
            directDevice?.stop()
            directDevice = nil
            isArmed = false
            showAdapterLost = false
        }
        console.isArmed = on
    }

    /// "Direct \u{00B7} /dev/cu.usbserial-A10K \u{00B7} 30 Hz", "Adapter lost", or the mode name.
    var outputStatus: String {
        switch outputMode {
        case .previewOnly: return "Preview only \u{2014} nothing is sent"
        case .consoleMIDI: return "Console \u{00B7} MIDI"
        case .directOpenDMX:
            guard let path = portPath else { return "Direct \u{00B7} no adapter chosen" }
            if let d = directDevice, !d.isConnected { return "Adapter lost" }
            return "Direct \u{00B7} \(path) \u{00B7} \(Int(refreshHz)) Hz"
        }
    }

    /// Debug value for UI tests: sum of the latest rendered frame.
    var frameSum: Int { runner.latestFrame().bytes.reduce(0) { $0 + Int($1) } }

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
