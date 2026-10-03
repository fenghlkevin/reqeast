// Original RHEQ send-time diagnostics and shareable report.
import SwiftUI

struct HttpDiagnosticsView: View {
    let execution: HttpExecutionState
    @State private var showingManual = false
    var body: some View {
        Section("Diagnostics") {
            Button("User Manual", systemImage: "book") { showingManual = true }.buttonStyle(.glass)
            if let error = execution.error {
                Label(error.localizedTitle, systemImage: error.iconName).foregroundStyle(.red)
                Text(HttpDiagnosticService.hint(for: error)).textSelection(.enabled)
                Text(error.message).font(.caption.monospaced()).foregroundStyle(.red).textSelection(.enabled)
            }
            if let duration = execution.diagnostic?.durationMs, execution.response == nil {
                LabeledContent("Duration", value: DurationFormat.abbreviated(fromMilliseconds: duration))
            }
            if let response = execution.response {
                LabeledContent("Status", value: "\(response.statusCode) \(response.statusText)")
                LabeledContent("Duration", value: response.formattedElapsed)
                if let timing = response.timing {
                    LabeledContent("DNS Lookup", value: DurationFormat.abbreviated(fromMilliseconds: timing.dnsLookupMs))
                    LabeledContent("Connect, TLS & Server Wait", value: DurationFormat.abbreviated(fromMilliseconds: timing.connectionMs))
                    LabeledContent("Download", value: DurationFormat.abbreviated(fromMilliseconds: timing.downloadMs))
                    Text("Connection, TLS handshake, redirects, and server wait are measured together. Separate TCP and TLS timings are unavailable.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HttpResponseCertificateSection(certificate: response.certificate)
                HttpResponseRedirectsSection(redirectChain: response.redirectChain.map {
                    StoredRedirectEntry(url: DiagnosticRedactionService.url($0.url), statusCode: $0.statusCode)
                })
            }
            if execution.diagnostic != nil || execution.response != nil || execution.error != nil {
                Text("Captured before redirects; transport-generated headers are not included.").font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("Sent Request") {
                    Text(verbatim: execution.diagnostic?.preparedRequest ?? String(localized: "No captured request is available. Send the request again."))
                        .font(.caption.monospaced()).textSelection(.enabled)
                }
                Button("Copy Redacted Diagnostics") {
                    PlatformClipboard.copy(HttpDiagnosticService.report(snapshot: execution.diagnostic,
                        response: execution.response, error: execution.error))
                }.buttonStyle(.glass)
                Text("Copied reports omit bodies, cookies, credentials, and URL query values. Review the report before sharing.")
                    .font(.caption).foregroundStyle(.secondary)
            } else { Text("Send a request to view diagnostics.") }
        }.sheet(isPresented: $showingManual) { HttpWorkflowGuide(initialTopic: 3) }
    }
}
