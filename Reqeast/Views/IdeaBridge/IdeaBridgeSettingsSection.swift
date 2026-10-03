#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct IdeaBridgeSettingsSection: View {
    @State private var document: IdeaPluginDocument?
    @State private var exporting = false
    @State private var showingManual = false
    @State private var error: RequestError?

    var body: some View {
        Section("IDEA Integration") {
            Button("Export IDEA Plugin") {
                do {
                    guard let url = Bundle.main.url(forResource: "rheq-controller-bridge-0.1.1", withExtension: "zip") else {
                        throw RequestError(kind: .invalidConfig, message: String(localized: "IDEA plugin package is missing."))
                    }
                    document = IdeaPluginDocument(data: try Data(contentsOf: url))
                    exporting = true
                } catch { self.error = RequestError.from(error) }
            }.buttonStyle(.glass)
            Button("Installation and Import Guide") { showingManual = true }.buttonStyle(.glass)
            if let error { Text(error.message).foregroundStyle(.red).textSelection(.enabled) }
        }
        .fileExporter(isPresented: $exporting, document: document, contentType: .zip, defaultFilename: "rheq-controller-bridge-0.1.1") { result in
            if case .failure(let failure) = result { error = RequestError.from(failure) }
        }
        .sheet(isPresented: $showingManual) { HttpWorkflowGuide(initialTopic: 5) }
    }
}

nonisolated struct IdeaPluginDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let bytes = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        data = bytes
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
#endif
