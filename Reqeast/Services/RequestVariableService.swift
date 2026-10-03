import Foundation

enum RequestVariableService {
    static func references(in data: HttpRequestData) -> [String] {
        func pairs(_ entries: [KeyValueEntry]) -> [String] {
            entries.filter { $0.enabled && !$0.key.isEmpty }.flatMap { [$0.key, $0.value] }
        }
        var inputs = [data.url] + pairs(data.headers) + pairs(data.params)
        let strict = UserDefaults.standard.object(forKey: "strictHttpMode") == nil || UserDefaults.standard.bool(forKey: "strictHttpMode")
        if !strict || data.method.conventionallyHasBody {
            switch data.bodyType {
            case .json, .raw: inputs.append(data.bodyContent)
            case .urlencoded: inputs += pairs(data.bodyFormData)
            case .formData: inputs += data.bodyFormDataEntries.filter { $0.enabled && !$0.key.isEmpty }.flatMap {
                $0.fieldType == .text ? [$0.key, $0.value] : [$0.key]
            }
            case .none, .binary: break
            }
        }
        switch data.authType {
        case .bearer: inputs.append(data.authToken)
        case .basic: inputs += [data.authUsername, data.authPassword]
        case .apiKey: inputs += [data.authApiKeyName, data.authApiKeyValue]
        case .jwtBearer: if let a = data.authData { inputs += [a.jwtSecret, a.jwtPayload] }
        case .hawkAuth: if let a = data.authData { inputs += [a.hawkAuthId, a.hawkAuthKey] }
        case .awsSignature: if let a = data.authData { inputs += [a.awsAccessKey, a.awsSecretKey, a.awsRegion, a.awsService, a.awsSessionToken] }
        case .akamaiEdgeGrid: if let a = data.authData { inputs += [a.akamaiClientToken, a.akamaiClientSecret, a.akamaiAccessToken] }
        default: break
        }
        let expression = try? NSRegularExpression(pattern: #"\{\{([^}]+)\}\}"#)
        return Set(inputs.flatMap { text in
            expression?.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
                Range($0.range(at: 1), in: text).map { String(text[$0]) }
            } ?? []
        }).sorted()
    }

    static func missing(in data: HttpRequestData, environment: ApiEnvironment?) -> [String] {
        let available = Set(environment?.variables.filter { $0.enabled && !($0.isSecret && $0.value.isEmpty) }.map(\.key) ?? [])
        return references(in: data).filter { !available.contains($0) }
    }

    static func resolveAuth(_ auth: HttpAuthData?, environment: ApiEnvironment?) -> HttpAuthData? {
        guard let auth, let bytes = try? JSONEncoder().encode(auth),
              var fields = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { return auth }
        for (key, value) in fields {
            if let text = value as? String { fields[key] = EnvironmentVariableService.substitute(text, environment: environment) }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: fields) else { return auth }
        return (try? JSONDecoder().decode(HttpAuthData.self, from: data)) ?? auth
    }
}
