import Foundation

/// RFC 6901 JSON pointers. Empty pointer selects the document; / selects an empty key.
nonisolated enum ResponseJSONService {
    static let maxBytes = 1_048_576

    static func parse(_ body: Data) throws -> Any {
        guard body.count <= maxBytes else {
            throw failure(String(localized: "JSON tools support responses up to 1 MB."))
        }
        do {
            return try JSONSerialization.jsonObject(with: body, options: .fragmentsAllowed)
        } catch {
            throw failure(String(localized: "The response is not valid JSON.") + "\n" + error.localizedDescription)
        }
    }

    static func value(at pointer: String, in document: Any) throws -> Any {
        if pointer.isEmpty { return document }
        guard pointer.hasPrefix("/") else {
            throw failure(String(localized: "A field path must start with /, for example /data/token."))
        }
        var current = document
        for component in pointer.dropFirst().split(separator: "/", omittingEmptySubsequences: false) {
            guard String(component).range(of: "~(?:[^01]|$)", options: .regularExpression) == nil else {
                throw failure(String(localized: "A field path must start with /, for example /data/token."))
            }
            let token = String(component).replacingOccurrences(of: "~1", with: "/")
                .replacingOccurrences(of: "~0", with: "~")
            if let dictionary = current as? [String: Any], let value = dictionary[token] {
                current = value
            } else if let array = current as? [Any], let index = Int(token),
                      String(index) == token, array.indices.contains(index) {
                current = array[index]
            } else {
                throw failure(String(localized: "JSON field not found:") + " " + pointer)
            }
        }
        return current
    }

    static func text(_ value: Any) throws -> String {
        if let string = value as? String { return string }
        let data = try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    static func fields(in document: Any) throws -> [String: String] {
        var fields: [String: String] = [:]
        func visit(_ value: Any, path: String, depth: Int) throws {
            guard depth < 64, fields.count < 2000 else {
                throw failure(String(localized: "This JSON is too complex to display. Choose a smaller response."))
            }
            if let dict = value as? [String: Any], !dict.isEmpty {
                for key in dict.keys.sorted() {
                    let escaped = key.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1")
                    guard let child = dict[key] else { continue }
                    try visit(child, path: path + "/" + escaped, depth: depth + 1)
                }
            } else if let array = value as? [Any], !array.isEmpty {
                for (index, child) in array.enumerated() {
                    try visit(child, path: path + "/\(index)", depth: depth + 1)
                }
            } else {
                // Preserve JSON types in comparisons: string "1" differs from number 1.
                let data = try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys])
                fields[path] = String(decoding: data, as: UTF8.self)
            }
        }
        try visit(document, path: "", depth: 0)
        return fields
    }

    static func failure(_ message: String) -> RequestError {
        RequestError(kind: .invalidConfig, message: message)
    }
}
