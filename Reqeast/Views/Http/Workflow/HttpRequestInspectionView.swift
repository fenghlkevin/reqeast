// Modified for RHEQ: visual workflows and HTTP diagnostics.
import SwiftUI

struct HttpRequestInspectionView: View {
    @Bindable var store: ProjectStore
    let request: Request
    @State private var revealSecrets = false
    @State private var selectedKey: String?
    private var environment: ApiEnvironment? { store.activeEnvironment(for: request.projectId) }

    var body: some View {
        Form {
            HttpDiagnosticsView(execution: SessionRegistry.shared.httpExecution(for: request.id))
            Section("Variable Sources") {
                if let data = request.httpData {
                    let references = RequestVariableService.references(in: data)
                    Text("Select a variable to see its value, source request, response field, and last update. Missing variables must be defined before sending.")
                    ForEach(references, id: \.self) { key in
                        DisclosureGroup(isExpanded: Binding(get: { selectedKey == key }, set: { selectedKey = $0 ? key : nil })) {
                            if let variable = environment?.variables.first(where: { $0.key == key && $0.enabled }) {
                                Text(verbatim: variable.isSecret && !revealSecrets ? "••••" : variable.value)
                                    .font(.body.monospaced()).textSelection(.enabled)
                                if let source = variable.source {
                                    LabeledContent("Source Request", value: source.requestName)
                                    LabeledContent("Response Field", value: source.pointer)
                                    LabeledContent("Last Updated") { Text(source.updatedAt, style: .date); Text(source.updatedAt, style: .time) }
                                } else { Text("Defined in the environment.") }
                            } else {
                                Text("Missing Variable").foregroundStyle(.red).textSelection(.enabled)
                            }
                        } label: { Text(verbatim: "{{\(key)}}") }
                    }
                    if references.isEmpty { Text("This request uses no variables.").foregroundStyle(.secondary) }
                }
            }
            Section("Request Preview") {
                Toggle("Show Secret Values", isOn: $revealSecrets)
                Text("Preview uses the same request preparation as Send. It shows the current environment, headers, cookies, and body before redirects. Signed credentials are generated again when sending.")
                    .font(.caption).foregroundStyle(.secondary)
                if let data = request.httpData {
                    let config = HttpSendPreparation.config(data: data, environment: environment,
                        sessionStore: SessionRegistry.shared.httpSession(for: request.id))
                    Text(verbatim: RequestPreviewService.text(config, environment: environment, hideSecrets: !revealSecrets, authApiKeyName: data.authType == .apiKey
                        ? EnvironmentVariableService.substitute(data.authApiKeyName, environment: environment) : ""))
                        .font(.body.monospaced()).textSelection(.enabled).accessibilityIdentifier("prepared-request-preview")
                    let missing = RequestVariableService.missing(in: data, environment: environment)
                    if !missing.isEmpty {
                        Text("Define the missing variables before sending.").foregroundStyle(.red).textSelection(.enabled)
                        Text(verbatim: missing.joined(separator: ", ")).foregroundStyle(.red).textSelection(.enabled)
                    }
                }
            }
        }.formStyle(.grouped).accessibilityIdentifier("workflow-inspection-form")
        .onAppear {
            #if DEBUG
            if WorkflowGuideDemo.isRequested, StorageEnvironment.isScreenshotMode { selectedKey = "token" }
            #endif
        }
    }
}
