import SwiftUI
import UniformTypeIdentifiers

struct PortableProjectView: View {
    @Bindable var store: ProjectStore
    let projectId: UUID
    @State private var exporting = false
    @State private var importing = false
    @State private var document: PortableProjectDocument?
    @State private var error: RequestError?
    @State private var message = ""

    var body: some View {
        Form {
            Section("Project Files") {
                Text("Export HTTP requests, environments, and saved workflows into a folder. Each request has a separate JSON file with stable names and sorted keys for Git review. Other protocols and attached files are not included.")
                Text("Secret variables are empty and inline credentials become variable references. Review URLs, headers, and bodies before sharing. Refill missing secrets locally or through CLI environment variables.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Export Project Folder") {
                    do { document = try PortableProjectDocument(files: PortableProjectService.files(store: store, projectId: projectId)); exporting = true }
                    catch { self.error = RequestError.from(error) }
                }.buttonStyle(.glass).accessibilityIdentifier("export-project-folder")
                Button("Import Project Folder") { importing = true }.buttonStyle(.glass).accessibilityIdentifier("import-project-folder")
                Text("Import creates a new project. Existing projects are kept. Export again to a new folder and review changes in Git before replacing tracked files.")
                    .font(.caption).foregroundStyle(.secondary)
                if !message.isEmpty { Text(verbatim: message).textSelection(.enabled) }
                if let error { Text(error.message).foregroundStyle(.red).textSelection(.enabled) }
            }
            Section("Command Line") {
                Text("Build reqeast-cli from the repository, then run an exported workflow by name. Use --data for CSV or JSON rows and --report for a JSON report. Exit codes: 0 passed, 1 failed checks or requests, 2 configuration error.")
                Text(verbatim: "cargo build --manifest-path rust/Cargo.toml --bin reqeast-cli --release")
                    .font(.caption.monospaced()).textSelection(.enabled)
                Text(verbatim: "reqeast-cli run ./api-project --workflow 'Order test' --environment 'Test' --data cases.csv --report run-report.json")
                    .font(.body.monospaced()).textSelection(.enabled)
                Text("Set secrets with REQEAST_VAR_token or a local JSON object via --secrets. Secret files are excluded by the exported .gitignore. Reports contain status and checks without response bodies or variable values.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
        .fileExporter(isPresented: $exporting, document: document, contentType: .folder, defaultFilename: "api-project") { result in
            switch result {
            case .success: message = String(localized: "Project folder exported."); error = nil
            case .failure(let error): self.error = RequestError.from(error)
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let project = try PortableProjectService.importCopy(url, store: store)
                message = String(localized: "Project imported as a new copy.") + " " + project.name; error = nil
            } catch { self.error = RequestError.from(error) }
        }
    }
}

struct PortableProjectDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.folder] }
    let wrapper: FileWrapper
    init(files: [String: Data]) throws {
        let requests = Dictionary(uniqueKeysWithValues: files.filter { $0.key.hasPrefix("requests/") }.map {
            (String($0.key.dropFirst("requests/".count)), FileWrapper(regularFileWithContents: $0.value))
        })
        var root = Dictionary(uniqueKeysWithValues: files.filter { !$0.key.contains("/") }.map { ($0.key, FileWrapper(regularFileWithContents: $0.value)) })
        root["requests"] = FileWrapper(directoryWithFileWrappers: requests)
        wrapper = FileWrapper(directoryWithFileWrappers: root)
    }
    init(configuration: ReadConfiguration) throws { wrapper = configuration.file }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { wrapper }
}
