// Original RHEQ response field linking without exposing field values.
import SwiftUI

struct ResponseLinkView: View {
    @Bindable var store: ProjectStore
    let request: Request
    let fields: [String]
    @State private var targetId: UUID?
    @State private var pointer = ""
    @State private var variable = "token"
    @State private var header = "Authorization"
    @State private var error: RequestError?
    @State private var saved = false
    private var targets: [Request] {
        store.requests(for: request.projectId).filter { $0.id != request.id && $0.type == .http && $0.httpData != nil }
    }
    var body: some View {
        DisclosureGroup("Use Response in Another Request") {
            Text("Choose a JSON field and a target request. RHEQ creates a secret extraction rule and a header reference. Authorization uses Bearer. Other headers use the variable directly.")
                .font(.caption).foregroundStyle(.secondary)
            ResponseFieldPicker(pointer: $pointer, fields: fields)
            Picker("Target Request", selection: $targetId) {
                ForEach(targets) { Text(verbatim: $0.name).tag(Optional($0.id)) }
            }.tint(.primary)
            TextField("Variable name", text: $variable).devTextInput()
            TextField("Header", text: $header).devTextInput()
            Button("Create Response Link") {
                do {
                    guard let targetId else { return }
                    try store.linkResponse(sourceId: request.id, targetId: targetId, pointer: pointer,
                        variable: variable, header: header)
                    error = nil; saved = true
                } catch { self.error = RequestError.from(error); saved = false }
            }.buttonStyle(.glass).disabled(targetId == nil || fields.isEmpty)
            if saved { Label("Response link saved. Run the source request before the target.", systemImage: "checkmark.circle").foregroundStyle(.green) }
            if let error { Text(error.message).foregroundStyle(.red).textSelection(.enabled) }
        }.onAppear { targetId = targets.first?.id; pointer = fields.first ?? "" }
        .onChange(of: fields) { if !fields.contains(pointer) { pointer = fields.first ?? "" } }
        .onChange(of: targets.map(\.id)) { if !targets.contains(where: { $0.id == targetId }) { targetId = targets.first?.id } }
    }
}
