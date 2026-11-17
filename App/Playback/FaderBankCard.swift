import SwiftUI
import AppKit
import ShowModel

/// Console-style fader banks: one fader per snapshot, per fixture or per saved effect.
struct FaderBankCard: View {
    let show: Show
    @ObservedObject var model: AppModel
    @SceneStorage("faderBank") private var bankRaw = Bank.snapshots.rawValue

    enum Bank: String, CaseIterable, Identifiable {
        case snapshots = "Snapshots", fixtures = "Fixtures", effects = "Effects"
        var id: String { rawValue }
    }

    private var bank: Bank { Bank(rawValue: bankRaw) ?? .snapshots }
    private static let fixtureTint = Color(red: 1, green: 0.9, blue: 0.7)

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.sm) {
                SectionHeader("Faders", systemImage: "slider.vertical.3") {
                    if bank == .fixtures {
                        Button("Clear") { model.clearFixtureFaders() }
                            .controlSize(.small)
                            .disabled(model.fixtureLevels.isEmpty)
                            .accessibilityIdentifier("clearFixtureFaders")
                    }
                    Picker("Bank", selection: $bankRaw) {
                        ForEach(Bank.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                    .focusable(false)   // keep Space / T / B on their buttons
                    .accessibilityIdentifier("faderBankPicker")
                }
                bankContent
            }
        }
    }

    @ViewBuilder private var bankContent: some View {
        switch bank {
        case .snapshots:
            row(show.snapshots, empty: "Record a look in the Programmer to get a snapshot fader.") { s in
                ConsoleFader(name: s.name, color: Color(hex: s.colorHex), identifier: "snapshotFader.\(s.name)",
                             level: Binding(get: { model.snapshotLevel(s.id) }, set: { model.setSnapshotLevel(s.id, $0) }))
            }
        case .fixtures:
            VStack(alignment: .leading, spacing: Space.sm) {
                if !show.patch.fixtures.isEmpty { PickedLightsColorBar(patch: show.patch, model: model) }
                HStack(alignment: .top, spacing: Space.sm) {
                    if !picked.isEmpty {
                        ConsoleFader(name: "Picked (\(picked.count))", color: .accentColor, identifier: "pickedFader",
                                     level: Binding(get: { picked.map { model.fixtureLevels[$0] ?? 0 }.max() ?? 0 },
                                                    set: { model.setFixtureLevel(picked, $0) }),
                                     picked: true)
                        Divider().frame(height: ConsoleFader.trackHeight + 60)
                    }
                    row(show.patch.fixtures, empty: "Patch some fixtures to get fixture faders.") { f in
                        ConsoleFader(name: f.name, color: model.fixtureColors[f.id].map(Color.init(rgb:)) ?? Self.fixtureTint,
                                     identifier: "fixtureFader.\(f.name)",
                                     level: Binding(get: { model.fixtureLevels[f.id] ?? 0 }, set: { model.setFixtureLevel(f.id, $0) }),
                                     picked: picked.contains(f.id),
                                     onNameTap: { togglePick(f.id) })
                    }
                }
            }
        case .effects:
            row(show.effects, empty: "Start an effect below and it gets a fader here.") { e in
                ConsoleFader(name: e.name, color: Color(hex: e.colorHex), identifier: "effectFader.\(e.name)",
                             level: Binding(get: { model.effectLevel(e.id) }, set: { model.setEffectFader(e.id, $0) }))
            }
        }
    }

    /// Lights picked on the Playback page (also used by the effect presets and the stage preview).
    private var picked: [UUID] {
        let known = Set(show.patch.fixtures.map(\.id))
        return model.effectTargets.filter { known.contains($0) }
    }

    private func togglePick(_ id: UUID) {
        if let i = model.effectTargets.firstIndex(of: id) { model.effectTargets.remove(at: i) }
        else { model.effectTargets.append(id) }
    }

    private func row<Item: Identifiable, Fader: View>(_ items: [Item], empty: String,
                                                      @ViewBuilder fader: @escaping (Item) -> Fader) -> some View {
        Group {
            if items.isEmpty {
                Text(empty).font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: Space.xs) {
                        ForEach(items) { fader($0) }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.automatic)
            }
        }
    }
}

/// One console fader strip: coloured cap that lights above 0, % readout, track, name.
/// Dragging moves it; the slider on top makes it adjustable for VoiceOver and UI tests.
struct ConsoleFader: View {
    let name: String
    let color: Color
    let identifier: String
    @Binding var level: Double
    var picked = false
    /// Clicking the name (e.g. to pick the light).
    var onNameTap: (() -> Void)? = nil

    static let trackHeight: CGFloat = 160

    private var percent: Int { Int((level * 100).rounded()) }

    var body: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(level > 0 ? color : Color.white.opacity(0.12))
                .frame(width: 30, height: 6)
                .shadow(color: level > 0 ? color.opacity(0.9) : .clear, radius: 5)
            Text("\(percent) %").font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(level > 0 ? Color.primary : Color.secondary)
            track
            Text(name).font(.caption2.weight(picked ? .bold : .regular)).lineLimit(2).multilineTextAlignment(.center)
                .frame(width: 56, height: 28, alignment: .top)
                .padding(.horizontal, 2)
                .background(RoundedRectangle(cornerRadius: 5).fill(picked ? Color.accentColor.opacity(0.35) : .clear))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(picked ? Color.accentColor : .clear, lineWidth: 1))
                .contentShape(Rectangle())
                .onTapGesture { onNameTap?() }
                .help(onNameTap == nil ? "" : "Click to pick or unpick this light")
                .accessibilityAddTraits(onNameTap == nil ? [] : .isButton)
                .accessibilityIdentifier("faderName.\(name)")
                .accessibilityValue(picked ? "picked" : "")
                .accessibilityAction { onNameTap?() }
        }
        .frame(width: 60)
    }

    /// The visuals are drawn here; a real (vertical, draws nothing) `NSSlider` on top takes the drag and is
    /// the accessibility element, so VoiceOver and XCUITest can adjust it (a drawn drag gesture is not reachable).
    private var track: some View {
        let knob: CGFloat = 16
        let travel = Self.trackHeight - knob
        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.35))
                .frame(width: 8, height: Self.trackHeight)
            RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.85))
                .frame(width: 8, height: knob / 2 + travel * level)
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(colors: [Color(white: 0.85), Color(white: 0.55)], startPoint: .top, endPoint: .bottom))
                .overlay(Rectangle().fill(color).frame(height: 2))
                .frame(width: 40, height: knob)
                .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                .offset(y: -travel * level)
            VerticalSlider(value: $level, label: name, identifier: identifier, valueText: "\(percent) %")
                .frame(width: 56, height: Self.trackHeight)
        }
        .frame(width: 56, height: Self.trackHeight)
    }
}

/// A vertical `NSSlider` (0...1). It reports a vertical orientation, so VoiceOver and XCUITest can adjust it.
/// Slider that takes input and accessibility but draws nothing; the fader strip draws itself underneath.
final class InvisibleSlider: NSSlider {
    override func draw(_ dirtyRect: NSRect) {}
}

struct VerticalSlider: NSViewRepresentable {
    @Binding var value: Double
    let label: String
    let identifier: String
    let valueText: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSSlider {
        let slider = InvisibleSlider(value: value, minValue: 0, maxValue: 1, target: context.coordinator,
                              action: #selector(Coordinator.changed(_:)))
        slider.isVertical = true
        slider.isContinuous = true
        slider.refusesFirstResponder = true   // never take Space / T / B from the page
        return slider
    }

    func updateNSView(_ slider: NSSlider, context: Context) {
        context.coordinator.parent = self
        if abs(slider.doubleValue - value) > 0.0001 { slider.doubleValue = value }
        slider.setAccessibilityLabel(label)
        slider.setAccessibilityIdentifier(identifier)
        slider.setAccessibilityValueDescription(valueText)
    }

    @MainActor final class Coordinator: NSObject {
        var parent: VerticalSlider
        init(_ parent: VerticalSlider) { self.parent = parent }
        @objc func changed(_ sender: NSSlider) { parent.value = min(max(sender.doubleValue, 0), 1) }
    }
}

/// Colour for the picked lights (all lights when none are picked): swatches, a custom colour, and back to
/// the colour from playbacks. Works with the faders: a dark par comes up in this colour when its fader rises.
struct PickedLightsColorBar: View {
    let patch: Patch
    @ObservedObject var model: AppModel
    @State private var custom = Color.white

    private var targets: [UUID] {
        let known = Set(patch.fixtures.map(\.id))
        let picked = model.effectTargets.filter { known.contains($0) }
        return picked.isEmpty ? patch.fixtures.map(\.id) : picked
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: Space.xs) {
                Text("Colour").font(.subheadline.weight(.semibold))
                Text(model.effectTargets.isEmpty ? "all lights" : "\(targets.count) picked")
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("colorTarget")
                Spacer()
                ColorPicker("Custom", selection: Binding(get: { custom }, set: { custom = $0; apply($0) }),
                            supportsOpacity: false)
                    .labelsHidden()
                    .help("Custom colour")
                    .accessibilityIdentifier("pickedCustomColor")
                Button { model.setFixtureColor(nil, for: targets) } label: {
                    Label("Original", systemImage: "arrow.uturn.backward")
                }
                .controlSize(.small)
                .help("Back to the colour from the playing looks")
                .disabled(!targets.contains { model.fixtureColors[$0] != nil })
                .accessibilityIdentifier("pickedColorReset")
            }
            HStack(spacing: 6) {
                ForEach(ColorControl.swatches, id: \.name) { s in
                    Button { apply(Color(hex: s.hex)) } label: {
                        Circle().fill(Color(hex: s.hex)).frame(width: 22, height: 22)
                            .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .help(s.name.capitalized)
                    .accessibilityLabel(s.name)
                    .accessibilityIdentifier("pickedSwatch.\(s.name)")
                }
            }
            Text(model.effectTargets.isEmpty ? "Click a light's name below (or on the stage) to pick it. Nothing picked: colour and the Picked fader act on all lights."
                                             : "Picked lights are highlighted. The Picked fader moves them all together.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func apply(_ c: Color) {
        let ns = NSColor(c).usingColorSpace(.sRGB) ?? .white
        model.setFixtureColor(RGB(r: Double(ns.redComponent), g: Double(ns.greenComponent), b: Double(ns.blueComponent)),
                              for: targets)
    }
}

extension Color {
    init(rgb: RGB) { self.init(red: rgb.r, green: rgb.g, blue: rgb.b) }
}
