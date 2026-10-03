import Foundation
import Testing
@testable import Reqeast

@Suite("IDEA Controller imports", .serialized)
@MainActor
struct IdeaBridgeTests {
    private let source = "0123456789abcdef01234567"

    private func bytes(path: String = "/orders", field: String = "name", version: Int = 1) throws -> Data {
        let operation: [String: Any] = [
            "operationId": "rheq-code:\(source):demo.OrderController#create():POST:0",
            "summary": "Create order", "parameters": [],
            "requestBody": ["content": ["application/json": ["schema": ["type": "object", "required": [field], "properties": [field: ["type": "string", "example": "demo"]]]]]],
            "responses": ["200": ["description": "OK"]]
        ]
        return try JSONSerialization.data(withJSONObject: [
            "openapi": "3.0.3", "info": ["title": "Orders", "version": "1"],
            "servers": [["url": "http://localhost:8080"]], "paths": [path: ["post": operation]],
            "x-rheq-bridge": ["version": version, "sourceId": source, "scope": "controller", "baseUrl": "http://localhost:8080", "warnings": []]
        ])
    }

    private func plan(_ preview: IdeaBridgePreview, target: Project? = nil, existing: [Request] = []) throws -> CodeImportPlan {
        try CodeImportMerge.plan(preview: preview, target: target, existing: existing,
            selected: Set(preview.spec.mapped.requests.compactMap { $0.specIdentity?.primaryKey }), baseURL: preview.descriptor.baseURL)
    }

    @Test func importsRealOpenAPIAndSynthesizesBody() async throws {
        let preview = try await IdeaBridgeImportService.preview(bytes: bytes())
        let result = try plan(preview)
        let request = try #require(result.requests.first)
        #expect(request.httpData?.url == "http://localhost:8080/orders")
        #expect(request.httpData?.bodyContent.contains("name") == true)
        #expect(request.codeImport?.sourceId == source)
        #expect(request.specIdentity == nil)
    }

    @Test func refreshPreservesCredentialsValuesWorkflowAndIdentity() async throws {
        let first = try plan(await IdeaBridgeImportService.preview(bytes: bytes()))
        var original = try #require(first.requests.first)
        original.httpData?.authType = .bearer
        original.httpData?.authToken = "user-test-token"
        original.httpData?.workflow.extractions = [ResponseExtraction(pointer: "/data/token", variable: "token")]
        original.httpData?.workflow.assertions = [ResponseAssertion(kind: .jsonValue, pointer: "/success", expected: "true")]
        original.httpData?.params = [KeyValueEntry(key: "limit", value: "50", enabled: false)]
        original.httpData?.bodyContent = "{\"name\":\"my test value\"}"
        original.name = "My order"
        original.isRenamed = true
        let next = try await IdeaBridgeImportService.preview(bytes: bytes(path: "/v2/orders", field: "title"))
        let result = try plan(next, target: first.project, existing: [original])
        let refreshed = try #require(result.requests.first)
        #expect(refreshed.id == original.id)
        #expect(refreshed.name == "My order")
        #expect(refreshed.httpData?.url == "http://localhost:8080/v2/orders")
        #expect(refreshed.httpData?.authToken == "user-test-token")
        #expect(refreshed.httpData?.params == original.httpData?.params)
        #expect(refreshed.httpData?.bodyContent == original.httpData?.bodyContent)
        #expect(refreshed.httpData?.workflow == original.httpData?.workflow)
    }

    @Test func unchangedRefreshHasNoWritesAndKeepsUserURL() async throws {
        let preview = try await IdeaBridgeImportService.preview(bytes: bytes())
        let first = try plan(preview)
        let repeatPreview = try await IdeaBridgeImportService.preview(bytes: bytes())
        #expect(try plan(repeatPreview, target: first.project, existing: first.requests).requests.isEmpty)
        var edited = first.requests
        edited[0].httpData?.url = "{{customHost}}/custom"
        let next = try await IdeaBridgeImportService.preview(bytes: bytes(path: "/v2/orders"))
        #expect(try plan(next, target: first.project, existing: edited).requests.first?.httpData?.url == "{{customHost}}/custom")
    }

    @Test func rejectUnsupportedEnvelopeAndLinkedTargets() async throws {
        #expect(throws: RequestError.self) { try IdeaBridgeImportService.descriptor(bytes: bytes(version: 2)) }
        #expect(!IdeaBridgeImportService.validBaseURL("https://name:password@example.test"))
        #expect(!IdeaBridgeImportService.validBaseURL("file:///tmp/api"))
        #expect(throws: RequestError.self) { try IdeaBridgeImportService.descriptor(bytes: Data(repeating: 32, count: IdeaBridgeImportService.maxBytes + 1)) }
        let preview = try await IdeaBridgeImportService.preview(bytes: bytes())
        var changed = try JSONSerialization.jsonObject(with: bytes()) as! [String: Any]
        var paths = changed["paths"] as! [String: Any]
        paths["/duplicate"] = paths["/orders"]
        changed["paths"] = paths
        #expect(throws: RequestError.self) { try IdeaBridgeImportService.descriptor(bytes: JSONSerialization.data(withJSONObject: changed)) }
        #expect(preview.spec.operationCount == 1)
        var linked = Project(name: "Linked")
        linked.specLink = SpecLink(format: .openapi, source: .url, contentFingerprint: "demo", importedAt: Date(), isDetached: false)
        #expect(throws: RequestError.self) { try plan(preview, target: linked) }
    }

    @Test func atomicCommitRollbackAndSourceIsolation() async throws {
        let preview = try await IdeaBridgeImportService.preview(bytes: bytes())
        let first = try plan(preview)
        let store = ProjectStore.mock()
        store.bulkImportSaveLocalShouldFail = true
        #expect(throws: BulkImportError.self) { try store.commitCodeImport(first) }
        #expect(store.projects.isEmpty && store.requests.isEmpty && !store.importInProgress)
        store.bulkImportSaveLocalShouldFail = false
        _ = try store.commitCodeImport(first)
        #expect(store.projects.count == 1 && store.requests.count == 1)
        var foreign = first.requests
        foreign[0].codeImport?.sourceId = "abcdef0123456789abcdef01"
        #expect(try plan(preview, target: first.project, existing: foreign).addedCount == 1)
        let before = store.bulkImportSaveLocalCallCount
        _ = try store.commitCodeImport(plan(preview, target: first.project, existing: store.requests))
        #expect(store.bulkImportSaveLocalCallCount == before)
    }

    @Test func legacyRequestsDecodeWithoutCodeLink() throws {
        let request = Request(projectId: UUID(), name: "Existing")
        let data = try JSONEncoder().encode(request)
        #expect(try JSONDecoder().decode(Request.self, from: data).codeImport == nil)
    }
}
