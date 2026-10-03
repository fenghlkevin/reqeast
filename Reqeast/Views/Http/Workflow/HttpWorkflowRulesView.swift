// Modified for RHEQ: visual workflows and HTTP diagnostics.
import SwiftUI

struct HttpWorkflowRulesView: View {
    @Bindable var store: ProjectStore
    let requestId: UUID
    @State private var fields: [String] = []
    @State private var error: RequestError?
    @State private var saved = false

    private var request: Request? { store.requests.first { $0.id == requestId && $0.deletedAt == nil } }
    private var execution: HttpExecutionState { SessionRegistry.shared.httpExecution(for: requestId) }
    private var workflow: Binding<HttpWorkflow> {
        Binding(get: { request?.httpData?.workflow ?? HttpWorkflow() }, set: { value in
            guard var updated = request else { return }
            updated.httpData?.workflow = value
            store.updateRequest(updated)
            saved = false
        })
    }

    var body: some View {
        Form {
            Section {
                Text("Choose a response field, name a variable, then use {{name}} in another request.")
                Text("Enabled extraction rules run after each successful HTTP response. Existing variables with the same name are replaced.")
                    .font(.caption).foregroundStyle(.secondary)
                if let request {
                    LabeledContent("Environment", value: store.activeEnvironment(for: request.projectId)?.name ?? String(localized: "Select an environment"))
                }
            }
            Section("Response Variables") {
                if let request { ResponseLinkView(store: store, request: request, fields: fields) }
                ForEach(workflow.extractions) { rule in
                    ResponseExtractionEditor(rule: rule, fields: fields) {
                        workflow.wrappedValue.extractions.removeAll { $0.id == rule.wrappedValue.id }
                    }
                }
                Button("Add Response Variable", systemImage: "plus") {
                    var rule = ResponseExtraction()
                    if let first = fields.first { rule.pointer = first }
                    workflow.wrappedValue.extractions.append(rule)
                }.buttonStyle(.glass).disabled(isReadOnly)
                Button("Save Variables from Current Response") { saveVariables() }
                    .buttonStyle(.glassProminent)
                    .disabled(execution.response == nil || workflow.wrappedValue.extractions.isEmpty || isReadOnly)
                if saved { Label("Variables saved.", systemImage: "checkmark.circle").foregroundStyle(.green) }
            }.disabled(isReadOnly || execution.isLoading)
            Section("Response Checks") {
                ForEach(workflow.assertions) { rule in
                    ResponseAssertionEditor(rule: rule, fields: fields) {
                        workflow.wrappedValue.assertions.removeAll { $0.id == rule.wrappedValue.id }
                    }
                }
                Button("Add Check", systemImage: "plus") {
                    workflow.wrappedValue.assertions.append(ResponseAssertion())
                }.buttonStyle(.glass).disabled(isReadOnly)
                Button("Check Current Response") {
                    if let response = execution.response {
                        execution.workflowChecks = HttpWorkflowService.checks(workflow.wrappedValue.assertions, response: response)
                    }
                }.buttonStyle(.glass).disabled(execution.response == nil)
                ForEach(execution.workflowChecks) { check in
                    WorkflowCheckRow(check: check)
                }
            }.disabled(isReadOnly || execution.isLoading)
            if let error = error ?? execution.workflowError {
                Section { Text(error.message).foregroundStyle(.red).textSelection(.enabled) }
            }
        }
        .formStyle(.grouped)
        .task(id: execution.response?.timestamp) { loadFields() }
    }

    private var isReadOnly: Bool { request.map { store.isSpecProjectReadOnly(projectId: $0.projectId) } ?? true }

    private func loadFields() {
        fields = []
        error = nil
        guard let response = execution.response else { return }
        do { fields = try ResponseJSONService.fields(in: ResponseJSONService.parse(response.body)).keys.sorted() }
        catch { self.error = RequestError.from(error) }
    }

    private func saveVariables() {
        error = nil
        saved = false
        guard let request, let response = execution.response else { return }
        do {
            try HttpWorkflowService.extract(workflow.wrappedValue.extractions, response: response,
                environment: store.activeEnvironment(for: request.projectId), store: store, request: request)
            saved = true
        } catch { self.error = RequestError.from(error) }
    }
}
