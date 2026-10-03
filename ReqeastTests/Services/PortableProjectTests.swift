import Foundation
import Testing
@testable import Reqeast

@Suite("Portable projects", .serialized)
@MainActor
struct PortableProjectTests {
    @Test func exportIsStableAndRemovesKnownSecrets() throws {
        let project = Project(name: "Orders")
        var request = Request(projectId: project.id, name: "Create")
        request.httpData = HttpRequestData(method: .post, url: "{{baseUrl}}/orders", headers: [
            KeyValueEntry(key: "Authorization", value: "Bearer inline-token"),
            KeyValueEntry(key: "X-Trace", value: "top-secret")], bodyType: .json,
            bodyContent: "{\"password\":\"inline-password\",\"product\":\"book\"}", authType: .bearer, authToken: "inline-token")
        let store = ProjectStore.mock(projects: [project], requests: [request])
        store.environments = [ApiEnvironment(projectId: project.id, name: "Test", variables: [
            EnvironmentVariable(key: "token", value: "top-secret", isSecret: true),
            EnvironmentVariable(key: "baseUrl", value: "https://example.test")])]
        let files = try PortableProjectService.files(store: store, projectId: project.id)
        #expect(files == (try PortableProjectService.files(store: store, projectId: project.id)))
        let combined = files.values.map { String(decoding: $0, as: UTF8.self) }.joined()
        for secret in ["inline-token", "inline-password", "top-secret"] { #expect(!combined.contains(secret)) }
        #expect(combined.contains("{{baseUrl}}/orders"))
        #expect(combined.contains("{{secret"))
    }
    @Test func roundTripCreatesCopyWithRewiredWorkflows() throws {
        var project = Project(name: "Round trip")
        let first = Request(projectId: project.id, name: "Login")
        let second = Request(projectId: project.id, name: "Order")
        let environment = ApiEnvironment(projectId: project.id, name: "Test", variables: [EnvironmentVariable(key: "token", value: "hidden", isSecret: true)])
        project.httpWorkflows = [SavedHttpWorkflow(name: "Order test", requestIds: [second.id, first.id], environmentId: environment.id)]
        let store = ProjectStore.mock(projects: [project], requests: [first, second]); store.environments = [environment]
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        for (path, data) in try PortableProjectService.files(store: store, projectId: project.id) {
            let url = folder.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
        }
        let copy = try PortableProjectService.importCopy(folder, store: store)
        #expect(copy.id != project.id)
        #expect(store.projects.count == 2)
        let ids = try #require(copy.httpWorkflows.first?.requestIds)
        #expect(ids.count == 2 && !ids.contains(first.id))
        #expect(store.requests.first { $0.id == ids[0] }?.name == "Order")
        #expect(copy.httpWorkflows[0].environmentId != environment.id)
        #expect(store.environments.last?.variables.first?.value == "")
        let unsupported = Data("{\"format\":99}".utf8)
        try unsupported.write(to: folder.appendingPathComponent("reqeast.json"))
        #expect(throws: (any Error).self) { try PortableProjectService.importCopy(folder, store: store) }
        #expect(store.projects.count == 2)
    }
    @Test func responseVariableProvenanceSurvivesEncoding() throws {
        let project = Project(name: "Sources")
        let request = Request(projectId: project.id, name: "Login")
        let environment = ApiEnvironment(projectId: project.id, name: "Test")
        let store = ProjectStore.mock(projects: [project]); store.environments = [environment]
        let source = ResponseVariableSource(requestId: request.id, requestName: request.name, pointer: "", updatedAt: Date())
        try store.saveResponseVariables([(ResponseExtraction(pointer: "/data/token"), "secret")], environmentId: environment.id, source: source)
        let decoded = try JSONDecoder().decode(ApiEnvironment.self, from: JSONEncoder().encode(store.environments[0]))
        #expect(decoded.variables.first?.source?.requestName == "Login")
        #expect(decoded.variables.first?.source?.pointer == "/data/token")
    }
}
