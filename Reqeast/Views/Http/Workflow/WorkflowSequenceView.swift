// Original RHEQ numbered workflow overview.
import SwiftUI

struct WorkflowSequenceView: View {
    let requests: [Request]
    let environment: ApiEnvironment?
    let runner: HttpRunnerState
    @State private var editingId: UUID?
    let store: ProjectStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(requests.enumerated()), id: \.element.id) { index, request in
                let result = runner.activeRequestId == request.id && runner.isRunning ? nil
                    : runner.results.last { $0.requestId == request.id }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(verbatim: "\(index + 1)").font(.headline.monospaced())
                            .frame(width: 28, height: 28).glassEffect(in: .circle)
                        Text(verbatim: request.name).font(.headline)
                        Spacer()
                        if runner.activeRequestId == request.id { ProgressView().controlSize(.small) }
                        if let result {
                            Image(systemName: result.passed ? "checkmark.circle" : "xmark.circle")
                                .foregroundStyle(result.passed ? .green : .red)
                        }
                        Button { editingId = request.id } label: { Image(systemName: "slider.horizontal.3") }
                            .buttonStyle(.glass).disabled(runner.isRunning)
                            .accessibilityLabel("Variables & Checks")
                    }
                    ForEach(WorkflowDependencyService.dependencies(for: request,
                        preceding: Array(requests.prefix(index)), environment: environment)) { dependency in
                        HStack(alignment: .top) {
                            Image(systemName: dependency.available ? "link" : "exclamationmark.triangle")
                                .foregroundStyle(dependency.available ? Color.secondary : Color.red)
                            VStack(alignment: .leading) {
                                Text(verbatim: "{{\(dependency.variable)}}").font(.caption.monospaced())
                                if let source = dependency.source {
                                    Text(verbatim: source.name + " → " + (dependency.pointer ?? ""))
                                } else { Text(dependency.available ? "Defined in the environment." : "Missing Variable") }
                            }.font(.caption).textSelection(.enabled)
                        }
                    }
                    if let result, !result.passed {
                        ForEach(result.checks.filter { !$0.passed }) { WorkflowCheckRow(check: $0) }
                        if let error = result.error { Text(error.message).foregroundStyle(.red).textSelection(.enabled) }
                    }
                }.padding(12).glassEffect(.regular, in: .rect(cornerRadius: 10))
                if index < requests.count - 1 { Image(systemName: "arrow.down").foregroundStyle(.secondary).padding(.leading, 18) }
            }
        }.sheet(isPresented: Binding(get: { editingId != nil }, set: { if !$0 { editingId = nil } })) {
            if let editingId {
                VStack {
                    HttpWorkflowRulesView(store: store, requestId: editingId)
                    Button("Close") { self.editingId = nil }.buttonStyle(.glass).padding()
                }
                #if os(macOS)
                .frame(width: 640, height: 650)
                #endif
            }
        }
    }
}
