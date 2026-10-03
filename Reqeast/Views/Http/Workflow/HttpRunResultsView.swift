import SwiftUI
import UniformTypeIdentifiers

struct HttpRunResultsView: View {
    @Bindable var runner: HttpRunnerState
    @State private var exporting = false
    @State private var error: RequestError?

    var body: some View {
        Section("Run Results") {
            if !runner.results.isEmpty {
                Button("Export Run Report") { exporting = true }.buttonStyle(.glass)
            }
            ForEach(runner.results) { result in
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: "#\(result.row)").font(.caption.monospaced()).accessibilityLabel(Text("Data Rows"))
                    Label(result.name, systemImage: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.passed ? .green : .red)
                    if let status = result.status, let elapsed = result.elapsed {
                        Text(verbatim: "HTTP \(status) · \(Int(elapsed)) ms").font(.caption.monospaced())
                    }
                    ForEach(result.checks) { WorkflowCheckRow(check: $0) }
                    if let error = result.error { Text(error.message).foregroundStyle(.red).textSelection(.enabled) }
                }.padding(.vertical, 4)
            }
            if let error { Text(error.message).foregroundStyle(.red).textSelection(.enabled) }
        }
        .fileExporter(isPresented: $exporting, document: WorkflowReportDocument(results: runner.results),
                      contentType: .json, defaultFilename: "reqeast-report") { result in
            if case .failure(let error) = result { self.error = RequestError.from(error) }
        }
    }
}

struct WorkflowReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(results: [HttpRunResult]) {
        let rows: [[String: Any]] = results.map { result in
            ["requestId": result.requestId.uuidString, "name": result.name, "row": result.row,
             "passed": result.passed, "status": result.status as Any? ?? NSNull(),
             "elapsedMs": result.elapsed as Any? ?? NSNull(),
             "checks": result.checks.map { ["passed": $0.passed] }]
        }
        data = (try? JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])) ?? Data("[]".utf8)
    }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
