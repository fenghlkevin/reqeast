import Foundation

@MainActor
enum PortableProjectService {
    static let maxBytes = 20 * 1_048_576

    static func files(store: ProjectStore, projectId: UUID) throws -> [String: Data] {
        guard let project = store.projects.first(where: { $0.id == projectId }) else {
            throw ResponseJSONService.failure(String(localized: "The selected project no longer exists."))
        }
        let requests = store.requests(for: projectId).filter { $0.type == .http && $0.httpData != nil }
        let environments = store.environments.filter { $0.projectId == projectId && $0.deletedAt == nil }
        let secrets = environments.flatMap(\.variables).filter(\.isSecret).map(\.value)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var files: [String: Data] = [:]
        for request in requests {
            guard let data = request.httpData else { continue }
            let sanitized = try PortableSecretService.sanitize(data, requestId: request.id, secrets: secrets)
            files["requests/\(request.id.uuidString).json"] = try encoder.encode(PortableRequest(id: request.id, name: request.name, httpData: sanitized))
        }
        let exported = environments.map { env in
            PortableEnvironment(id: env.id, name: env.name, variables: env.variables.map { variable in
                var copy = variable; copy.source = nil
                if copy.isSecret { copy.value = "" }
                else {
                    for secret in secrets.filter({ !$0.isEmpty }).sorted(by: { $0.count > $1.count }) {
                        copy.value = copy.value.replacingOccurrences(of: secret, with: "{{secret}}")
                    }
                }
                return copy
            })
        }
        let manifest = PortableProject(name: project.name, requestIds: requests.map(\.id), workflows: project.httpWorkflows, environments: exported)
        files["reqeast.json"] = try encoder.encode(manifest)
        files[".gitignore"] = Data(".env\nsecrets.json\n*-report.json\n.DS_Store\n".utf8)
        guard files.values.reduce(0, { $0 + $1.count }) <= maxBytes else { throw invalid() }
        return files
    }

    static func read(_ root: URL) throws -> (PortableProject, [PortableRequest]) {
        var total = 0
        func readFile(_ url: URL) throws -> Data {
            let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
            guard values.isSymbolicLink != true, let size = values.fileSize, size <= maxBytes - total else { throw invalid() }
            total += size
            return try Data(contentsOf: url)
        }
        let manifest = try JSONDecoder().decode(PortableProject.self, from: readFile(root.appendingPathComponent("reqeast.json")))
        guard manifest.format == 1, manifest.requestIds.count <= 10_000,
              Set(manifest.requestIds).count == manifest.requestIds.count else { throw invalid() }
        let requestsRoot = root.appendingPathComponent("requests")
        guard try requestsRoot.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw invalid() }
        let requests = try manifest.requestIds.map { id in
            let request = try JSONDecoder().decode(PortableRequest.self, from: readFile(requestsRoot.appendingPathComponent("\(id.uuidString).json")))
            guard request.id == id else { throw invalid() }
            return request
        }
        guard manifest.workflows.allSatisfy({ workflow in !workflow.requestIds.isEmpty && Set(workflow.requestIds).count == workflow.requestIds.count
                  && Set(workflow.requestIds).isSubset(of: Set(manifest.requestIds))
                  && (workflow.environmentId == nil || manifest.environments.contains { $0.id == workflow.environmentId }) }),
              Set(manifest.environments.map(\.id)).count == manifest.environments.count else { throw invalid() }
        return (manifest, requests)
    }

    static func importCopy(_ root: URL, store: ProjectStore) throws -> Project {
        let (manifest, portable) = try read(root)
        var project = Project(name: manifest.name)
        let requestIds = Dictionary(uniqueKeysWithValues: portable.map { ($0.id, UUID()) })
        let environmentIds = Dictionary(uniqueKeysWithValues: manifest.environments.map { ($0.id, UUID()) })
        let requests = portable.enumerated().map { index, source in
            var request = Request(id: requestIds[source.id] ?? UUID(), projectId: project.id, name: source.name, sortOrder: index)
            request.httpData = source.httpData; request.isRenamed = true
            return request
        }
        let environments = manifest.environments.map { source in
            ApiEnvironment(id: environmentIds[source.id] ?? UUID(), projectId: project.id, name: source.name,
                           variables: source.variables, isActive: source.id == manifest.environments.first?.id)
        }
        project.httpWorkflows = manifest.workflows.map { source in
            var copy = source; copy.id = UUID(); copy.requestIds = source.requestIds.compactMap { requestIds[$0] }
            copy.environmentId = source.environmentId.flatMap { environmentIds[$0] }
            return copy
        }
        if store.isInMemory {
            store.projects.append(project); store.requests += requests; store.environments += environments
        } else { try store.performBulkImport(project: project, folders: [], requests: requests, environments: environments) }
        return project
    }

    static func invalid() -> RequestError { ResponseJSONService.failure(String(localized: "Invalid project folder or unsupported format. Limit: 20 MB.")) }
}
