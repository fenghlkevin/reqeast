import Foundation

enum RequestPreviewService {
    static func text(_ config: HttpRequestConfig, environment: ApiEnvironment?, hideSecrets: Bool, authApiKeyName: String = "") -> String {
        var url = config.url
        if hideSecrets, var components = URLComponents(string: url) {
            if components.user != nil { components.user = "••••" }
            if components.password != nil { components.password = "••••" }
            components.queryItems = components.queryItems?.map { item in
                URLQueryItem(name: item.name, value: PortableSecretService.sensitiveKey(item.name) || item.name == authApiKeyName ? "••••" : item.value)
            }
            url = components.string ?? url
        }
        var lines = [config.method.rawLabel + " " + url]
        lines += config.headers.map { $0.key + ": " + $0.value }
        if !config.cookies.isEmpty { lines.append("Cookie: " + config.cookies.map { $0.key + "=" + $0.value }.joined(separator: "; ")) }
        lines.append("")
        switch config.body {
        case .none: break
        case .json(let content), .raw(let content, _): lines.append(content)
        case .formUrlencoded(let fields): lines += fields.map { $0.key + "=" + $0.value }
        case .binary(let data, _): lines.append("[\(String(localized: "Binary")): \(data.count) B]")
        case .multipart(let fields):
            lines += fields.map { $0.name + ": " + ($0.isFile ? "[\(String(localized: "File")): \($0.fileName ?? "") · \($0.value.count) B]" : String(decoding: $0.value, as: UTF8.self)) }
        }
        guard hideSecrets else { return lines.joined(separator: "\n") }
        // Mask credentials in headers as well as secret values used in URLs and bodies.
        lines = lines.map { line in
            let key = line.components(separatedBy: ":").first?.lowercased() ?? ""
            return (["authorization", "proxy-authorization", "cookie", "x-api-key"].contains(key) || !authApiKeyName.isEmpty && key == authApiKeyName.lowercased()) ? key + ": ••••" : line
        }
        var text = lines.joined(separator: "\n")
        for variable in (environment?.variables ?? []).filter({ $0.isSecret && !$0.value.isEmpty }).sorted(by: { $0.value.count > $1.value.count }) {
            text = text.replacingOccurrences(of: variable.value, with: "••••")
            if let encoded = variable.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                text = text.replacingOccurrences(of: encoded, with: "••••")
            }
        }
        return text
    }
}
