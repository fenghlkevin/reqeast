import CryptoKit
import Foundation

struct CodeImportMetadata: Codable, Hashable {
    var sourceId: String
    var operationId: String
    var baseline: CodeRequestBaseline
}

struct CodeRequestBaseline: Codable, Hashable {
    var url: String
    var name: String
    var bodyFingerprint: String
    var parameterKeys: [String]
    var headerKeys: [String]

    init(request: Request) {
        let data = request.httpData ?? HttpRequestData()
        url = data.url
        name = request.name
        bodyFingerprint = Self.bodyFingerprint(data)
        parameterKeys = data.params.map(\.key)
        headerKeys = data.headers.map { $0.key.lowercased() }
    }

    static func bodyFingerprint(_ data: HttpRequestData) -> String {
        let form = data.bodyFormData.map { [$0.key, $0.value, String($0.enabled)] }
        let parts = data.bodyFormDataEntries.map { [$0.key, $0.value, String($0.enabled), $0.fieldType.rawValue, $0.fileName, $0.mimeType] }
        let values: [[String]] = [[data.bodyType.rawValue, data.bodyContent, data.rawContentType?.rawValue ?? "", data.binaryFileName], form.flatMap { $0 }, parts.flatMap { $0 }]
        let bytes = (try? JSONEncoder().encode(values)) ?? Data()
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}
