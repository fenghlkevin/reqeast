import SwiftUI

struct HttpRunnerRequestRow: View {
    let request: Request
    let position: Int?
    @Binding var selected: Set<UUID>
    let move: (Int) -> Void

    var body: some View {
        HStack {
            if let position {
                Text(verbatim: String(position)).font(.caption.monospacedDigit().bold())
                    .frame(width: 28, height: 28).glassEffect()
                    .accessibilityLabel(Text("Execution Order"))
                    .accessibilityValue(Text(verbatim: String(position)))
            }
            Toggle(isOn: Binding(get: { selected.contains(request.id) }, set: { value in
                if value { selected.insert(request.id) } else { selected.remove(request.id) }
            })) {
                VStack(alignment: .leading) {
                    Text(request.name)
                    Text(request.httpData?.url ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }.accessibilityIdentifier("workflow-request-\(request.id)")
            Button { move(-1) } label: { Label("Move Up", systemImage: "arrow.up") }.labelStyle(.iconOnly)
            Button { move(1) } label: { Label("Move Down", systemImage: "arrow.down") }.labelStyle(.iconOnly)
        }
    }
}
