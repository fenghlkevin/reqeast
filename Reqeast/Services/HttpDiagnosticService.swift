// Original RHEQ request diagnostics, using captured send-time metadata.
import Foundation

struct HttpDiagnosticSnapshot {
    let timestamp: Date
    let preparedRequest: String
    let secrets: [String]
    var durationMs: Double?
}

enum HttpDiagnosticService {
    static func snapshot(config: HttpRequestConfig, data: HttpRequestData, environment: ApiEnvironment?) -> HttpDiagnosticSnapshot {
        var secrets = environment?.variables.filter(\.isSecret).map(\.value) ?? []
        secrets += [data.authToken, data.authPassword, data.authApiKeyValue].map {
            EnvironmentVariableService.substitute($0, environment: environment)
        }
        secrets += config.headers.filter { PortableSecretService.sensitiveKey($0.key) }.map(\.value)
        secrets += config.cookies.map(\.value)
        let preview = RequestPreviewService.text(config, environment: environment, hideSecrets: true,
            authApiKeyName: data.authType == .apiKey ? EnvironmentVariableService.substitute(data.authApiKeyName, environment: environment) : "")
        // Omit request bodies from shareable diagnostics: arbitrary payloads can contain private values.
        return HttpDiagnosticSnapshot(timestamp: Date(), preparedRequest: DiagnosticRedactionService.text(preview, secrets: secrets), secrets: secrets)
    }

    static func hint(for error: RequestError) -> String {
        switch error.kind {
        case .tlsError: String(localized: "Check the certificate hostname, expiry, and trusted issuer. The full TLS error is shown below.")
        case .connectionFailed: String(localized: "Check the hostname, port, DNS, VPN, and whether the server is listening.")
        case .timeout: String(localized: "The timeout does not identify a single failed phase. Check connectivity and server response time.")
        case .invalidConfig: String(localized: "Check the URL, headers, required variables, and attached files before sending again.")
        default: String(localized: "Review the error chain and response status before retrying.")
        }
    }

    static func report(snapshot: HttpDiagnosticSnapshot?, response: HttpResponseData?, error: RequestError?) -> String {
        let secrets = snapshot?.secrets ?? []
        var lines = ["RHEQ HTTP diagnostics"]
        if let snapshot {
            lines += [snapshot.timestamp.ISO8601Format(), snapshot.preparedRequest.components(separatedBy: "\n\n").first ?? snapshot.preparedRequest]
            if let duration = snapshot.durationMs { lines.append("Elapsed: \(duration) ms") }
        }
        if let error { lines += [error.localizedTitle, DiagnosticRedactionService.text(error.message, secrets: secrets), hint(for: error)] }
        if let response {
            lines += ["Status: \(response.statusCode)", "HTTP: " + response.httpVersion,
                "Final URL: " + DiagnosticRedactionService.url(response.finalUrl)]
            if let timing = response.timing {
                lines += ["DNS: \(timing.dnsLookupMs) ms", "Connect + TLS + wait: \(timing.connectionMs) ms", "Download: \(timing.downloadMs) ms"]
            }
            lines += response.redirectChain.map { "\($0.statusCode) " + DiagnosticRedactionService.url($0.url) }
            if let certificate = response.certificate {
                lines += ["Certificate: " + (certificate.subjectCn ?? ""), "Issuer: " + (certificate.issuerCn ?? ""), "Expires: " + (certificate.validUntil ?? "")]
            }
        }
        return DiagnosticRedactionService.text(lines.joined(separator: "\n"), secrets: secrets)
    }
}
