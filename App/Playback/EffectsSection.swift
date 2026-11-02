import SwiftUI
import ShowModel

/// Effect buttons for the Playback page: preset chases and overlays, saved effects, and the running list.
struct EffectsSection: View {
    @Binding var document: ShowDocument
    @ObservedObject var model: AppModel

    private var patch: Patch { document.show.patch }
    /// Programmer selection (in selection order); every patched fixture when nothing is selected.
    private var targetIDs: [UUID] {
        model.programmer.selection.isEmpty ? patch.fixtures.map(\.id) : model.programmer.selection
    }
    private var targetText: String {
        model.programmer.selection.isEmpty ? "all \(patch.fixtures.count) fixtures"
                                           : "\(model.programmer.selection.count) selected"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Effects").font(.title3.bold())
                Text("on \(targetText)").font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("effectsTarget")
                Spacer()
                TapTempoButton(model: model)
            }
            if !model.runningEffects.isEmpty {
                Text("Running").font(.headline)
                ForEach(model.runningEffects, id: \.effectID) { r in
                    if let e = document.show.effects.first(where: { $0.id == r.effectID }) {
                        RunningEffectRow(effect: e, model: model)
                    }
                }
            }
            group("Chases", .chase)
            group("Overlays", .overlay)
            if !document.show.effects.isEmpty {
                Text("Saved effects").font(.headline)
                EffectGrid(items: document.show.effects) { e in
                    EffectButton(title: e.name, subtitle: "\(e.fixtureIDs.count) fx", colorHex: e.colorHex,
                                 isOn: model.isRunning(e.id), identifier: "effectButton.\(e.name)") {
                        model.toggleEffect(e)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("effectsSection")
    }

    private func group(_ title: String, _ category: EffectPresetCategory) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            EffectGrid(items: EffectPresets.all.filter { $0.category == category }) { preset in
                EffectButton(title: preset.name, subtitle: nil, colorHex: preset.colorHex,
                             isOn: existing(preset).map { model.isRunning($0.id) } ?? false,
                             identifier: "effectPreset.\(preset.name)") { fire(preset) }
            }
        }
    }

    private func existing(_ preset: EffectPreset) -> Effect? {
        document.show.effects.first { $0.name == preset.name && $0.fixtureIDs == targetIDs }
    }

    /// Creates the preset's effect for the target fixtures if needed, then toggles it.
    private func fire(_ preset: EffectPreset) {
        if let e = existing(preset) { model.toggleEffect(e); return }
        let ids = targetIDs
        guard !ids.isEmpty else { model.showToast("Patch some fixtures first"); return }
        let e = preset.makeEffect(fixtureIDs: ids)
        document.show.effects.append(e)
        model.startEffect(e)
    }
}

/// A big colour-coded button for one effect.
struct EffectButton: View {
    let title: String
    let subtitle: String?
    let colorHex: String
    let isOn: Bool
    let identifier: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title).font(.headline).lineLimit(2).multilineTextAlignment(.center)
                if let subtitle { Text(subtitle).font(.caption).opacity(0.8) }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: colorHex).opacity(isOn ? 1 : 0.28)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isOn ? Color.yellow : Color.clear, lineWidth: 2))
            .foregroundStyle(isOn ? Color.black : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(isOn ? "on" : "off")
    }
}

/// One running effect: effect master slider and stop button.
struct RunningEffectRow: View {
    let effect: Effect
    @ObservedObject var model: AppModel

    var body: some View {
        HStack {
            Circle().fill(Color(hex: effect.colorHex)).frame(width: 12, height: 12)
            Text(effect.name).frame(width: 130, alignment: .leading).lineLimit(1)
            Slider(value: Binding(get: { model.effectLevel(effect.id) }, set: { model.setEffectLevel(effect.id, $0) }),
                   in: 0...1)
                .accessibilityIdentifier("effectLevel.\(effect.name)")
                .accessibilityValue("\(Int((model.effectLevel(effect.id) * 100).rounded())) %")
            Text("\(Int((model.effectLevel(effect.id) * 100).rounded())) %").monospacedDigit()
                .frame(width: 48, alignment: .trailing)
            Button { model.stopEffect(effect.id) } label: { Image(systemName: "stop.fill") }
                .accessibilityLabel("Stop \(effect.name)")
                .accessibilityIdentifier("effectStop.\(effect.name)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("runningEffect.\(effect.name)")
    }
}

/// Four-column grid that is not lazy, so every button is always in the accessibility tree.
struct EffectGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @ViewBuilder var content: (Item) -> Content
    private let columns = 4

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(Array(stride(from: 0, to: items.count, by: columns)), id: \.self) { start in
                GridRow {
                    ForEach(items[start..<min(start + columns, items.count)]) { content($0) }
                    ForEach(0..<(start + columns - min(start + columns, items.count)), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, minHeight: 1)
                    }
                }
            }
        }
    }
}
