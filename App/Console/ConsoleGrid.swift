import SwiftUI
import ShowModel

/// 15 bank rows x 8 scenes, plus a row of 6 chases. A cell is lit when the console is believed on.
struct ConsoleGrid: View {
    let map: ConsoleMap
    let mode: ConsoleMode
    @Binding var selection: Set<ConsoleTarget>
    @Binding var editingTarget: ConsoleTarget?
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(1...15, id: \.self) { bank in
                HStack(spacing: 4) {
                    Text("B\(bank)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 28)
                    ForEach(1...8, id: \.self) { scene in cell(.scene(bank: bank, scene: scene)) }
                }
            }
            HStack(spacing: 4) {
                Text("Ch").font(.caption).foregroundStyle(.secondary).frame(width: 28)
                ForEach(1...6, id: \.self) { chase in cell(.chase(chase)) }
            }
            .padding(.top, 8)
        }
    }

    private func cell(_ target: ConsoleTarget) -> some View {
        let info = map.cells[target]
        let isOn = model.console.state.on.contains(target)
        let isSelected = selection.contains(target)
        let base = Color(hex: info?.colorHex ?? "#808080")
        return Button {
            switch mode {
            case .play: Task { await model.fire(target) }
            case .edit: editingTarget = target
            case .select:
                if isSelected { selection.remove(target) } else { selection.insert(target) }
            }
        } label: {
            Text(info?.name.isEmpty == false ? info!.name : target.shortTitle)
                .font(.caption).lineLimit(2).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 34)
                .padding(2)
                .background(RoundedRectangle(cornerRadius: 6).fill(base.opacity(isOn ? 1 : 0.28)))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.white : (isOn ? Color.yellow : Color.clear), lineWidth: 2))
                .foregroundStyle(isOn ? Color.black : Color.primary)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 64)
        .accessibilityIdentifier(target.identifier)
        .accessibilityLabel(info?.name.isEmpty == false ? info!.name : target.shortTitle)
        .accessibilityValue(isOn ? "on" : "off")
    }
}
