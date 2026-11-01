import SwiftUI
import AppKit
import ShowModel

/// One big snapshot button. Click = exclusive recall; shift-click = layer/unlayer.
struct PlaybackButton: View {
    let snapshot: Snapshot
    let slot: Int            // 1...16 on the page
    let isOn: Bool
    let isSelected: Bool
    var onFire: (_ layered: Bool) -> Void

    var body: some View {
        let base = Color(hex: snapshot.colorHex)
        let button = Button {
            onFire(NSEvent.modifierFlags.contains(.shift))
        } label: {
            VStack(spacing: 2) {
                Text(snapshot.name).font(.headline).lineLimit(2).multilineTextAlignment(.center)
                Text(String(format: "%.1f s", snapshot.defaultFade)).font(.caption).opacity(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 8).fill(base.opacity(isOn ? 1 : 0.28)))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(isOn ? Color.yellow : (isSelected ? Color.white.opacity(0.7) : Color.clear), lineWidth: 2))
            .foregroundStyle(isOn ? Color.black : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(snapshot.name)
        .accessibilityIdentifier("playbackButton.\(snapshot.name)")
        .accessibilityValue(isOn ? "on" : "off")
        if slot <= 9, let key = Character(String(slot)).asciiValue {
            button.keyboardShortcut(KeyEquivalent(Character(UnicodeScalar(key))), modifiers: [])
        } else {
            button
        }
    }
}
