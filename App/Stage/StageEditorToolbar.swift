import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ShowModel

/// Buttons above the stage: background image import/removal. A plain view (not a `.toolbar` item).
struct StageEditorToolbar: View {
    @Binding var document: ShowDocument

    var body: some View {
        HStack {
            Label("Stage", systemImage: "theatermasks").font(.headline)
            Spacer()
            Button { chooseBackground() } label: { Label("Set background\u{2026}", systemImage: "photo") }
                .accessibilityIdentifier("setBackground")
            if document.show.stage.backgroundFileName != nil {
                Button {
                    document.backgroundImageData = nil
                    document.show.stage.backgroundFileName = nil
                } label: { Label("Remove background", systemImage: "trash") }
            }
        }
        .controlSize(.small)
        .padding(Space.sm)
    }

    private func chooseBackground() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
        // Only accept data that decodes as an image.
        guard NSImage(data: data) != nil else { return }
        let ext = url.pathExtension.lowercased() == "png" ? "png" : "jpg"
        document.backgroundImageData = data
        document.show.stage.backgroundFileName = "background.\(ext)"
    }
}
