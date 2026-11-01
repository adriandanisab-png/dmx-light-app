import SwiftUI
import UniformTypeIdentifiers
import ShowModel

extension UTType {
    static let dmxShow = UTType(exportedAs: "app.dmxbridge.show")
}

/// A `.dmxshow` package: a directory containing `show.json`.
/// Opening a corrupt or newer-version file throws, which SwiftUI shows as an error; nothing is sent.
struct ShowDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.dmxShow]
    static let fileName = "show.json"

    var show: Show
    /// Contents of `show.stage.backgroundFileName`, stored as a second file in the package.
    var backgroundImageData: Data?

    init(show: Show = Show()) { self.show = show }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.fileWrappers?[Self.fileName]?.regularFileContents else {
            throw ShowFileError.corrupt
        }
        show = try Show.decode(data)
        if let name = show.stage.backgroundFileName {
            backgroundImageData = configuration.file.fileWrappers?[name]?.regularFileContents
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let json = FileWrapper(regularFileWithContents: try show.encode())
        json.preferredFilename = Self.fileName
        var files = [Self.fileName: json]
        if let name = show.stage.backgroundFileName, let data = backgroundImageData {
            let image = FileWrapper(regularFileWithContents: data)
            image.preferredFilename = name
            files[name] = image
        }
        return FileWrapper(directoryWithFileWrappers: files)
    }
}
