import SwiftUI
import ShowModel

@main
struct DMXBridgeApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: ShowDocument()) { file in
            ShowRootView(document: file.$document)
        }
    }
}
