import Foundation

enum HttpUrlInputService {
    /// Recognize a command even when pasted into an existing URL without selecting it first.
    static func parseCommand(_ input: String, replacing previousURL: String) throws -> ParsedImportResult? {
        let old = Array(previousURL)
        let new = Array(input)
        var prefix = 0
        while prefix < min(old.count, new.count), old[prefix] == new[prefix] {
            prefix += 1
        }
        var suffix = 0
        while suffix < min(old.count - prefix, new.count - prefix),
              old[old.count - suffix - 1] == new[new.count - suffix - 1] {
            suffix += 1
        }
        let inserted = String(new[prefix..<(new.count - suffix)])
        if !previousURL.isEmpty, prefix + suffix == old.count,
           ImportRequestService.detectFormat(inserted) == .curl {
            return try ImportRequestService.parse(inserted)
        }
        guard ImportRequestService.detectFormat(input) == .curl else { return nil }
        return try ImportRequestService.parse(input)
    }
}
