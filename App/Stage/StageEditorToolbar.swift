import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ShowModel

/// Buttons above the stage: background image import/removal. A plain view (not a `.toolbar` item).
struct StageEditorToolbar: View {
    @Binding var document: ShowDocument

    var body: some View {
        HStack {
            Text("Stage").font(.headline)
            Spacer()
            Button("Set background\u{2026}") { chooseBackground() }
                .accessibilityIdentifier("setBackground")
            if document.show.stage.backgroundFileName != nil {
                Button("Remove background") {
                    document.backgroundImageData = nil
                    document.show.stage.backgroundFileName = nil
                }
            }
        }
        .padding(8)
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
