import Foundation

struct IdeaBridgeDescriptor: Equatable {
    var sourceId: String
    var baseURL: String
    var warnings: [String]
}

struct IdeaBridgePreview {
    var descriptor: IdeaBridgeDescriptor
    var spec: SpecImportPreview
}

enum IdeaBridgeImportService {
    nonisolated static let maxBytes = 5 * 1024 * 1024

    static func descriptor(bytes: Data) throws -> IdeaBridgeDescriptor {
        guard bytes.count <= maxBytes,
              let json = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              let bridge = json["x-rheq-bridge"] as? [String: Any],
              let version = bridge["version"] as? Int, version == 1,
              let source = bridge["sourceId"] as? String,
              source.range(of: "^[0-9a-f]{24}$", options: .regularExpression) != nil,
              let scope = bridge["scope"] as? String, ["method", "controller", "module"].contains(scope),
              let base = bridge["baseUrl"] as? String, validBaseURL(base),
              let paths = json["paths"] as? [String: [String: Any]],
              let warnings = bridge["warnings"] as? [String], warnings.count <= 10000,
              warnings.allSatisfy({ $0.utf8.count <= 8192 }) else {
            throw RequestError(kind: .invalidConfig, message: String(localized: "Invalid IDEA interface export."))
        }
        var identities = Set<String>()
        for operations in paths.values {
            for (verb, value) in operations where ["get", "post", "put", "patch", "delete", "head", "options"].contains(verb) {
                guard let operation = value as? [String: Any], let identity = operation["operationId"] as? String,
                      identity.hasPrefix("rheq-code:\(source):"), identity.utf8.count <= 4096,
                      identities.insert(identity).inserted, identities.count <= 2000 else {
                    throw RequestError(kind: .invalidConfig, message: String(localized: "Invalid IDEA interface export."))
                }
            }
        }
        guard !identities.isEmpty else {
            throw RequestError(kind: .invalidConfig, message: String(localized: "No interfaces to import."))
        }
        return IdeaBridgeDescriptor(sourceId: source, baseURL: base, warnings: warnings)
    }

    static func validBaseURL(_ value: String) -> Bool {
        guard let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil, url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else { return false }
        return value.utf8.count <= 4096
    }

    static func preview(bytes: Data) async throws -> IdeaBridgePreview {
        let metadata = try descriptor(bytes: bytes)
        var options = SpecImportOptions.default
        options.scaffoldAuth = false
        options.enableSchemaSynthesis = true
        options.enableOptionalParameters = true
        options.createEnvironments = false
        let spec = try await SpecImportService.preview(bytes: bytes, sourceHint: .openApi, source: .file, options: options)
        return IdeaBridgePreview(descriptor: metadata, spec: spec)
    }

    @concurrent
    static func read(_ url: URL) async throws -> Data {
        guard url.isFileURL, url.pathExtension.lowercased() == "rheqapi" else {
            throw RequestError(kind: .invalidConfig, message: String(localized: "Invalid IDEA interface export."))
        }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true, let size = values.fileSize, size <= maxBytes else {
            throw RequestError(kind: .invalidConfig, message: String(localized: "IDEA exports must be smaller than 5 MB."))
        }
        let data = try Data(contentsOf: url)
        guard data.count <= maxBytes else {
            throw RequestError(kind: .invalidConfig, message: String(localized: "IDEA exports must be smaller than 5 MB."))
        }
        return data
    }
}
