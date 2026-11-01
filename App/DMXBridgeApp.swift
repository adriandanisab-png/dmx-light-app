import SwiftUI
import ShowModel

@main
struct DMXBridgeApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: ShowDocument()) { file in
            // Placeholder until the Config and Console tabs arrive (plan 1, tasks 8-9).
            Text("DMX Bridge: \(file.document.show.patch.fixtures.count) fixtures")
                .frame(minWidth: 800, minHeight: 500)
        }
    }
}
