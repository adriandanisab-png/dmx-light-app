import SwiftUI
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
            row(show.patch.fixtures, empty: "Patch some fixtures to get fixture faders.") { f in
                ConsoleFader(name: f.name, color: Self.fixtureTint, identifier: "fixtureFader.\(f.name)",
                             level: Binding(get: { model.fixtureLevels[f.id] ?? 0 }, set: { model.setFixtureLevel(f.id, $0) }))
            }
        case .effects:
            row(show.effects, empty: "Start an effect below and it gets a fader here.") { e in
                ConsoleFader(name: e.name, color: Color(hex: e.colorHex), identifier: "effectFader.\(e.name)",
                             level: Binding(get: { model.effectLevel(e.id) }, set: { model.setEffectFader(e.id, $0) }))
            }
        }
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
/// Dragging moves it; VoiceOver and UI tests adjust it by 10 % through a slider representation.
struct ConsoleFader: View {
    let name: String
    let color: Color
    let identifier: String
    @Binding var level: Double

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
            Text(name).font(.caption2).lineLimit(2).multilineTextAlignment(.center)
                .frame(width: 56, height: 28, alignment: .top)
        }
        .frame(width: 60)
        .accessibilityRepresentation {
            Slider(value: $level, in: 0...1, step: 0.1)
                .accessibilityLabel(name)
                .accessibilityValue("\(percent) %")
                .accessibilityIdentifier(identifier)
        }
    }

    private var track: some View {
        GeometryReader { geo in
            let knob: CGFloat = 16
            let travel = geo.size.height - knob
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.35))
                    .frame(width: 8)
                    .frame(maxHeight: .infinity)
                RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.85))
                    .frame(width: 8, height: knob / 2 + travel * level)
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [Color(white: 0.85), Color(white: 0.55)], startPoint: .top, endPoint: .bottom))
                    .overlay(Rectangle().fill(color).frame(height: 2))
                    .frame(width: 40, height: knob)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                    .offset(y: -travel * level)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let fraction = 1 - (g.location.y - knob / 2) / travel
                level = min(max(fraction, 0), 1)
            })
        }
        .frame(width: 56, height: Self.trackHeight)
    }
}
