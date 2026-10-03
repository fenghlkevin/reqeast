import SwiftUI

struct HttpComparisonView: View {
    let requestId: UUID
    @State private var baseline: HttpResponseData?
    @State private var ignored = ""
    @State private var differences: [ResponseDifference] = []
    @State private var error: RequestError?
    @State private var compared = false
    @State private var busy = false
    private var current: HttpResponseData? { SessionRegistry.shared.httpExecution(for: requestId).response }

    var body: some View {
        Form {
            Section("Baseline Response") {
                Text("Save a response as a baseline. Send again, then compare JSON fields and the HTTP status.")
                if let baseline {
                    LabeledContent("Saved", value: baseline.timestamp.formatted(date: .abbreviated, time: .shortened))
                    Text(baseline.finalUrl).font(.caption).textSelection(.enabled)
                }
                Button(baseline == nil ? String(localized: "Save Current Response as Baseline") : String(localized: "Replace Baseline with Current Response")) {
                    saveBaseline()
                }.buttonStyle(.glass).disabled(current == nil || busy)
                Text("The baseline is stored on this device and may contain response data.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Compare Responses") {
                TextField("Ignored paths, separated by commas", text: $ignored).devTextInput()
                Text("Example: /timestamp, /requestId. A path also ignores all fields below it.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Compare with Baseline") { compare() }
                    .buttonStyle(.glassProminent).disabled(baseline == nil || current == nil || busy)
                if busy { ProgressView() }
                if compared && differences.isEmpty { Label("No differences.", systemImage: "checkmark.circle") }
                ForEach(differences) { difference in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(verbatim: difference.path.isEmpty ? "(JSON)" : difference.path).font(.headline.monospaced())
                        if let before = difference.before {
                            Text(verbatim: "− " + String(before.prefix(2000))).foregroundStyle(.red)
                        }
                        if let after = difference.after {
                            Text(verbatim: "+ " + String(after.prefix(2000))).foregroundStyle(.green)
                        }
                    }.font(.caption.monospaced()).textSelection(.enabled)
                }
                if let error { Text(error.message).foregroundStyle(.red).textSelection(.enabled) }
            }
        }.formStyle(.grouped)
        .task {
            do { baseline = try SessionPersistenceService.shared.loadBaseline(for: requestId) }
            catch { self.error = RequestError.from(error) }
        }
        .onChange(of: current?.timestamp) { _, _ in compared = false; differences = [] }
    }

    private func saveBaseline() {
        guard let current else { return }
        do {
            try SessionPersistenceService.shared.saveBaseline(current, for: requestId)
            baseline = current
            error = nil
            compared = false
            differences = []
        } catch { self.error = RequestError.from(error) }
    }

    private func compare() {
        guard let baseline, let current else { return }
        error = nil
        busy = true
        compared = false
        let paths = Set(ignored.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        Task {
            defer { busy = false }
            do {
                guard paths.allSatisfy({ $0.hasPrefix("/") }) else {
                    throw ResponseJSONService.failure(String(localized: "A field path must start with /, for example /data/token."))
                }
                differences = try await ResponseComparisonService.compare(baseline, current, ignoring: paths)
                compared = true
            } catch { self.error = RequestError.from(error) }
        }
    }
}
