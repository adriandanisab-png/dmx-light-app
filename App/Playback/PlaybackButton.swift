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
            TileLabel(title: snapshot.name, caption: String(format: "%.1f s", snapshot.defaultFade))
        }
        .buttonStyle(TileButtonStyle(color: base, isOn: isOn, isSelected: isSelected))
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
