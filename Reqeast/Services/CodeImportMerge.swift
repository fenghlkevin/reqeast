import Foundation

struct CodeImportPlan {
    var project: Project
    var isNewProject: Bool
    var requests: [Request]
    var addedCount: Int
    var updatedCount: Int
}

enum CodeImportMerge {
    static func plan(preview: IdeaBridgePreview, target: Project?, existing: [Request],
                     selected: Set<String>, baseURL: String) throws -> CodeImportPlan {
        guard IdeaBridgeImportService.validBaseURL(baseURL), target?.specLink == nil else {
            throw RequestError(kind: .invalidConfig, message: String(localized: "Choose a local project and a valid base URL."))
        }
        let project = target ?? preview.spec.mapped.project
        let source = preview.descriptor.sourceId
        var result: [Request] = []
        var added = 0
        var updated = 0
        for mapped in preview.spec.mapped.requests {
            guard let identity = mapped.specIdentity?.primaryKey, selected.contains(identity), var http = mapped.httpData else { continue }
            var incoming = mapped
            incoming.projectId = project.id
            incoming.folderId = nil
            http.url = http.url.replacingOccurrences(of: "{{base_url}}", with: baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
            incoming.httpData = http
            incoming.specIdentity = nil
            incoming.specFieldFingerprint = nil
            incoming.specSnapshotPayload = nil
            incoming.specLastSyncedAt = nil
            let baseline = CodeRequestBaseline(request: incoming)
            let metadata = CodeImportMetadata(sourceId: source, operationId: identity, baseline: baseline)
            let matches = existing.filter { $0.projectId == project.id && $0.deletedAt == nil
                && $0.codeImport?.sourceId == source && $0.codeImport?.operationId == identity }
            guard matches.count <= 1 else {
                throw RequestError(kind: .invalidConfig, message: String(localized: "Duplicate interface links. Resolve them before refreshing."))
            }
            if let original = matches.first, let previous = original.codeImport?.baseline, var current = original.httpData {
                var merged = original
                current.method = http.method
                if current.url == previous.url { current.url = http.url }
                if CodeRequestBaseline.bodyFingerprint(current) == previous.bodyFingerprint
                    && baseline.bodyFingerprint != previous.bodyFingerprint {
                    current.bodyType = http.bodyType
                    current.bodyContent = http.bodyContent
                    current.bodyFormData = http.bodyFormData
                    current.bodyFormDataEntries = http.bodyFormDataEntries
                    current.rawContentType = http.rawContentType
                }
                current.params = appendNew(current.params, incoming: http.params, baselineKeys: previous.parameterKeys, headers: false)
                current.headers = appendNew(current.headers, incoming: http.headers, baselineKeys: previous.headerKeys, headers: true)
                if !merged.isRenamed && merged.name == previous.name { merged.name = incoming.name }
                merged.httpData = current
                merged.codeImport = metadata
                if merged != original { result.append(merged); updated += 1 }
            } else {
                incoming.codeImport = metadata
                incoming.sortOrder = (existing.filter { $0.projectId == project.id }.map(\.sortOrder).max() ?? -1) + added + 1
                result.append(incoming)
                added += 1
            }
        }
        return CodeImportPlan(project: project, isNewProject: target == nil, requests: result, addedCount: added, updatedCount: updated)
    }

    private static func appendNew(_ current: [KeyValueEntry], incoming: [KeyValueEntry], baselineKeys: [String], headers: Bool) -> [KeyValueEntry] {
        func key(_ value: String) -> String { headers ? value.lowercased() : value }
        let known = Set(current.map { key($0.key) } + baselineKeys)
        return current + incoming.filter { !$0.key.isEmpty && !known.contains(key($0.key)) }
    }
}
