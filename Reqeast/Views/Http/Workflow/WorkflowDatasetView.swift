import SwiftUI
import UniformTypeIdentifiers

struct WorkflowDatasetView: View {
    @Binding var dataset: WorkflowDataset?
    @State private var importing = false
    @State private var error: RequestError?

    var body: some View {
        Section("Test Data") {
            Text("Each data row runs the whole workflow. Column names replace variables for that row. Extracted values stay within the row; your saved environment is unchanged.")
                .font(.callout)
            HStack {
                Button("Import CSV or JSON") { importing = true }.buttonStyle(.glass).accessibilityIdentifier("import-workflow-data")
                if dataset != nil { Button("Clear Test Data") { dataset = nil; error = nil }.buttonStyle(.glass) }
            }
            if let dataset {
                LabeledContent("Data Rows", value: String(dataset.rows.count))
                Text(verbatim: dataset.columns.joined(separator: ", ")).font(.caption.monospaced())
                Text("Data values are hidden. Review the input file before running.").font(.caption).foregroundStyle(.secondary)
            }
            if let error { Text(error.message).foregroundStyle(.red).textSelection(.enabled) }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .json], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
                dataset = try WorkflowDatasetService.parse(bytes, isJSON: url.pathExtension.lowercased() == "json")
                error = nil
            } catch { self.error = RequestError.from(error) }
        }
    }
}
