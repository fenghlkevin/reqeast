import SwiftUI

struct ResponseExtractionEditor: View {
    @Binding var rule: ResponseExtraction
    let fields: [String]
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Enabled", isOn: $rule.enabled)
                Spacer()
                Button(role: .destructive, action: remove) { Label("Delete", systemImage: "trash") }
                    .buttonStyle(.glass)
            }
            ResponseFieldPicker(pointer: $rule.pointer, fields: fields)
            TextField("Variable name", text: $rule.variable).devTextInput()
            Toggle("Secret variable", isOn: $rule.isSecret)
        }.padding(.vertical, 4)
    }
}

struct ResponseAssertionEditor: View {
    @Binding var rule: ResponseAssertion
    let fields: [String]
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Enabled", isOn: $rule.enabled)
                Spacer()
                Button(role: .destructive, action: remove) { Label("Delete", systemImage: "trash") }
                    .buttonStyle(.glass)
            }
            Picker("Check", selection: $rule.kind) {
                ForEach(ResponseAssertionKind.allCases, id: \.self) { Text($0.localizedName).tag($0) }
            }.tint(.primary)
            if rule.kind == .jsonValue { ResponseFieldPicker(pointer: $rule.pointer, fields: fields) }
            TextField("Expected value", text: $rule.expected).devTextInput()
        }.padding(.vertical, 4)
    }
}

struct ResponseFieldPicker: View {
    @Binding var pointer: String
    let fields: [String]

    var body: some View {
        if !fields.isEmpty {
            Picker("Response field", selection: $pointer) {
                ForEach(Array(Set(fields + [pointer])).sorted(), id: \.self) { path in
                    Text(verbatim: path.isEmpty ? "(JSON)" : path).tag(path)
                }
            }.tint(.primary)
        }
        TextField("Field path (for example /data/token)", text: $pointer).devTextInput()
    }
}

struct WorkflowCheckRow: View {
    let check: WorkflowCheck
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(check.label, systemImage: check.passed ? "checkmark.circle" : "xmark.circle")
                .foregroundStyle(check.passed ? .green : .red)
            Text(check.detail).font(.caption.monospaced()).textSelection(.enabled)
        }
    }
}
