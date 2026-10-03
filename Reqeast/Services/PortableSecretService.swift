import Foundation

/// Exported credentials are references. Secret values never become project files.
enum PortableSecretService {
    static func sanitize(_ data: HttpRequestData, requestId: UUID, secrets: [String]) throws -> HttpRequestData {
        let bytes = try JSONEncoder().encode(data)
        let object = try JSONSerialization.jsonObject(with: bytes)
        let fields = Set(["authToken", "authUsername", "authPassword", "authApiKeyValue", "jwtSecret", "hawkAuthKey",
                          "awsAccessKey", "awsSecretKey", "awsSessionToken", "akamaiClientToken", "akamaiClientSecret", "akamaiAccessToken"])
        func reference(_ text: String, _ name: String) -> String {
            if text.isEmpty || text.hasPrefix("{{") && text.hasSuffix("}}") { return text }
            return "{{secret_\(requestId.uuidString.prefix(8))_\(name)}}"
        }
        func scrub(_ value: Any) -> Any {
            if let text = value as? String {
                return secrets.filter { !$0.isEmpty }.sorted { $0.count > $1.count }.reduce(text) { result, secret in
                    result.replacingOccurrences(of: secret, with: "{{secret}}")
                }
            }
            if let array = value as? [Any] { return array.map(scrub) }
            guard var map = value as? [String: Any] else { return value }
            for (key, value) in map { map[key] = scrub(value) }
            for key in fields {
                if let text = map[key] as? String { map[key] = reference(text, key) }
            }
            if let key = map["key"] as? String, sensitiveKey(key), let text = map["value"] as? String {
                map["value"] = reference(text, key.lowercased().filter { $0.isLetter || $0.isNumber })
            }
            return map
        }
        var sanitized = scrub(object) as? [String: Any] ?? [:]
        if data.bodyType == .json, let body = data.bodyContent.data(using: .utf8),
           let bodyJSON = try? JSONSerialization.jsonObject(with: body) {
            func scrubBody(_ value: Any) -> Any {
                if let array = value as? [Any] { return array.map(scrubBody) }
                guard let map = value as? [String: Any] else { return scrub(value) }
                return map.mapValues { scrubBody($0) }.merging(map.filter { sensitiveKey($0.key) }.mapValues { _ in "{{secret}}" }) { _, new in new }
            }
            let cleaned = try JSONSerialization.data(withJSONObject: scrubBody(bodyJSON), options: [.sortedKeys])
            sanitized["bodyContent"] = String(decoding: cleaned, as: UTF8.self)
        }
        if var url = URLComponents(string: sanitized["url"] as? String ?? "") {
            if url.user != nil { url.user = "{{username}}" }
            if url.password != nil { url.password = "{{password}}" }
            url.queryItems = url.queryItems?.map { item in
                URLQueryItem(name: item.name, value: sensitiveKey(item.name) ? reference(item.value ?? "", item.name) : item.value)
            }
            sanitized["url"] = url.string?.replacingOccurrences(of: "%7B", with: "{").replacingOccurrences(of: "%7D", with: "}") ?? sanitized["url"]
        }
        let cleaned = try JSONSerialization.data(withJSONObject: sanitized)
        return try JSONDecoder().decode(HttpRequestData.self, from: cleaned)
    }

    static func sensitiveKey(_ key: String) -> Bool {
        let normalized = key.lowercased().filter { $0.isLetter || $0.isNumber }
        return ["authorization", "proxyauthorization", "cookie", "setcookie", "xapikey", "apikey", "password", "passwd", "secret", "token", "accesstoken", "refreshtoken", "clientsecret"].contains(normalized)
    }
}
