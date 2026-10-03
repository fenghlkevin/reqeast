// Original RHEQ diagnostic redaction. Reports never include response bodies.
import Foundation

enum DiagnosticRedactionService {
    static func text(_ input: String, secrets: [String]) -> String {
        var result = input
        for secret in secrets.filter({ !$0.isEmpty }).sorted(by: { $0.count > $1.count }) {
            result = result.replacingOccurrences(of: secret, with: "••••")
            for allowed in [CharacterSet.urlQueryAllowed, CharacterSet.alphanumerics] {
                if let encoded = secret.addingPercentEncoding(withAllowedCharacters: allowed) {
                    result = result.replacingOccurrences(of: encoded, with: "••••")
                }
            }
        }
        // Error chains may contain redirect targets or URLs with credentials.
        if let regex = try? NSRegularExpression(pattern: #"https?://[^\s<>]+"#) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard let range = Range(match.range, in: result) else { continue }
                result.replaceSubrange(range, with: url(String(result[range])))
            }
        }
        return result
    }

    static func url(_ value: String) -> String {
        guard var parts = URLComponents(string: value) else { return "••••" }
        parts.user = nil; parts.password = nil; parts.fragment = nil
        parts.queryItems = parts.queryItems?.map { URLQueryItem(name: $0.name, value: $0.value == nil ? nil : "••••") }
        return parts.string ?? "••••"
    }
}
