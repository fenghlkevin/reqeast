// Original RHEQ atomic response-to-request links.
import Foundation

extension ProjectStore {
    func linkResponse(sourceId: UUID, targetId: UUID, pointer: String, variable: String, header: String) throws {
        guard let sourceIndex = requests.firstIndex(where: { $0.id == sourceId && $0.deletedAt == nil }),
              let targetIndex = requests.firstIndex(where: { $0.id == targetId && $0.deletedAt == nil }),
              sourceId != targetId, requests[sourceIndex].projectId == requests[targetIndex].projectId,
              requests[sourceIndex].httpData != nil, requests[targetIndex].httpData != nil,
              !isSpecProjectReadOnly(projectId: requests[sourceIndex].projectId),
              !variable.isEmpty, !variable.contains(where: { $0.isWhitespace || $0 == "{" || $0 == "}" }),
              !header.isEmpty, header.unicodeScalars.allSatisfy({
                  $0.isASCII && (CharacterSet.alphanumerics.contains($0) || "!#$%&' *+-.^_`|~".replacingOccurrences(of: " ", with: "").unicodeScalars.contains($0))
              }) else {
            throw ResponseJSONService.failure(String(localized: "Choose two editable HTTP requests and valid variable and header names."))
        }
        guard pointer.isEmpty || pointer.hasPrefix("/") else {
            throw ResponseJSONService.failure(String(localized: "A field path must start with /, for example /data/token."))
        }
        let previousSource = requests[sourceIndex], previousTarget = requests[targetIndex]
        var source = previousSource, target = previousTarget
        var rule = source.httpData?.workflow.extractions.first { $0.variable == variable } ?? ResponseExtraction()
        rule.pointer = pointer; rule.variable = variable; rule.enabled = true; rule.isSecret = true
        source.httpData?.workflow.extractions.removeAll { $0.variable == variable }
        source.httpData?.workflow.extractions.append(rule)
        if header.caseInsensitiveCompare("Authorization") == .orderedSame {
            // Use one header source, so saved auth settings cannot add a second Authorization value.
            target.httpData?.authType = HttpAuthType.none
        }
        target.httpData?.headers.removeAll { $0.key.caseInsensitiveCompare(header) == .orderedSame }
        target.httpData?.headers.append(KeyValueEntry(key: header,
            value: header.caseInsensitiveCompare("Authorization") == .orderedSame ? "Bearer {{\(variable)}}" : "{{\(variable)}}"))
        source.touch(); target.touch()
        requests[sourceIndex] = source; requests[targetIndex] = target
        do { if !isInMemory { try saveLocalOrThrow() } }
        catch { requests[sourceIndex] = previousSource; requests[targetIndex] = previousTarget; throw error }
        if !isInMemory { CloudSyncService.shared.queueSave(source); CloudSyncService.shared.queueSave(target) }
    }
}
