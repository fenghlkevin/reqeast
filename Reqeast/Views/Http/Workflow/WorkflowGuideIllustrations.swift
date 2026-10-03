import SwiftUI

struct WorkflowGuideStep<Illustration: View>: View {
    let number: Int
    let title: LocalizedStringKey
    let text: LocalizedStringKey
    @ViewBuilder let illustration: () -> Illustration

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text(verbatim: String(number)).font(.headline)
                    .frame(width: 32, height: 32).glassEffect(in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.headline)
                    Text(text).fixedSize(horizontal: false, vertical: true)
                }
            }
            illustration()
            Divider()
        }
    }
}

struct WorkflowExamplePanel: View {
    let title: LocalizedStringKey
    let icon: String
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.caption.bold()).foregroundStyle(.secondary)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(verbatim: line).font(.system(.callout, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(.secondary.opacity(0.25)) }
        .textSelection(.enabled)
    }
}

struct WorkflowComparisonExample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Compare Responses", systemImage: "arrow.left.arrow.right").font(.caption.bold())
            Text(verbatim: "/price").font(.headline.monospaced())
            HStack(spacing: 16) {
                Text(verbatim: "− 12").foregroundStyle(.red)
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                Text(verbatim: "+ 15").foregroundStyle(.green)
            }.font(.title2.monospaced())
            HStack {
                Label("Baseline Response", systemImage: "pin")
                Spacer()
                Label("Response", systemImage: "arrow.down.circle")
            }.font(.caption).foregroundStyle(.secondary)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(.secondary.opacity(0.25)) }
    }
}
