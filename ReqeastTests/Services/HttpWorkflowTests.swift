import Foundation
import Testing
@testable import Reqeast

@Suite("HTTP workflows", .serialized)
@MainActor
struct HttpWorkflowTests {
    static func response(_ json: String, status: Int = 200, elapsed: Double = 50) -> HttpResponseData {
        HttpResponseData(statusCode: status, statusText: "OK", headers: [], body: Data(json.utf8),
            elapsedMs: elapsed, bodySize: Int64(json.utf8.count), finalUrl: "https://example.test", timestamp: Date(),
            cookies: [], httpVersion: "HTTP/2", remoteAddr: nil)
    }

    @Test func pointersSupportEscapedKeysArraysAndRoot() throws {
        let document = try ResponseJSONService.parse(Data(#"{"a/b":{"~key":[false,"hello"]},"":"empty"}"#.utf8))
        #expect(try ResponseJSONService.text(ResponseJSONService.value(at: "/a~1b/~0key/1", in: document)) == "hello")
        #expect(try ResponseJSONService.text(ResponseJSONService.value(at: "/", in: document)) == "empty")
        #expect(throws: RequestError.self) { try ResponseJSONService.value(at: "/a~1b/~0key/01", in: document) }
        #expect(throws: RequestError.self) { try ResponseJSONService.value(at: "a", in: document) }
    }

    @Test func oldRequestsDecodeWithoutWorkflowAndRulesRoundTrip() throws {
        var data = HttpRequestData()
        data.workflow.extractions = [ResponseExtraction()]
        data.workflow.assertions = [ResponseAssertion()]
        let bytes = try JSONEncoder().encode(data)
        #expect(try JSONDecoder().decode(HttpRequestData.self, from: bytes).workflow == data.workflow)
        var old = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        old.removeValue(forKey: "workflow")
        let decoded = try JSONDecoder().decode(HttpRequestData.self, from: JSONSerialization.data(withJSONObject: old))
        #expect(decoded.workflow == HttpWorkflow())
    }

    @Test func failedExtractionDoesNotPartiallyOverwriteVariables() throws {
        let project = Project(name: "Workflow")
        let environment = ApiEnvironment(projectId: project.id, name: "Test",
            variables: [EnvironmentVariable(key: "token", value: "old", isSecret: true)], isActive: true)
        let store = ProjectStore.mock(projects: [project])
        store.environments = [environment]
        var missing = ResponseExtraction()
        missing.pointer = "/missing"
        missing.variable = "other"
        #expect(throws: RequestError.self) {
            try HttpWorkflowService.extract([ResponseExtraction(), missing], response: Self.response(#"{"token":"new"}"#),
                environment: environment, store: store)
        }
        #expect(store.environments[0] == environment)
    }

    @Test func extractionPreservesSecretAndIsUsableByNextRequest() throws {
        let project = Project(name: "Workflow")
        let environment = ApiEnvironment(projectId: project.id, name: "Test",
            variables: [EnvironmentVariable(key: "token", value: "old", isSecret: true)], isActive: true)
        let store = ProjectStore.mock(projects: [project])
        store.environments = [environment]
        var rule = ResponseExtraction()
        rule.isSecret = false
        try HttpWorkflowService.extract([rule], response: Self.response(#"{"token":"new"}"#), environment: environment, store: store)
        #expect(store.environments[0].variables[0].isSecret)
        #expect(EnvironmentVariableService.substitute("Bearer {{token}}", environment: store.activeEnvironment(for: project.id)) == "Bearer new")
    }

    @Test func nullAndDuplicateVariableNamesFailWithoutMutation() throws {
        let project = Project(name: "Workflow")
        let environment = ApiEnvironment(projectId: project.id, name: "Test", isActive: true)
        let store = ProjectStore.mock(projects: [project])
        store.environments = [environment]
        #expect(throws: RequestError.self) {
            try HttpWorkflowService.extract([ResponseExtraction()], response: Self.response(#"{"token":null}"#), environment: environment, store: store)
        }
        #expect(throws: RequestError.self) {
            try HttpWorkflowService.extract([ResponseExtraction(), ResponseExtraction()], response: Self.response(#"{"token":"a"}"#), environment: environment, store: store)
        }
        #expect(store.environments[0].variables.isEmpty)
    }

    @Test func checksReportMissingFieldsAndInvalidLimits() {
        var field = ResponseAssertion()
        field.kind = .jsonValue
        field.pointer = "/success"
        field.expected = "true"
        var time = ResponseAssertion()
        time.kind = .elapsed
        time.expected = "50"
        let checks = HttpWorkflowService.checks([ResponseAssertion(), field, time], response: Self.response(#"{"success":true}"#))
        #expect(checks.map(\.passed) == [true, true, false])
        field.pointer = "/missing"
        #expect(!HttpWorkflowService.checks([field], response: Self.response("{}"))[0].passed)
        time.expected = "invalid"
        #expect(!HttpWorkflowService.checks([time], response: Self.response("{}"))[0].passed)
    }

    @Test func comparisonPreservesJSONTypesAndIgnoresOnlyRequestedSubtree() async throws {
        let old = Self.response(#"{"value":"1","meta":{"time":1},"metadata":1,"items":[1,2]}"#)
        let new = Self.response(#"{"value":1,"meta":{"time":2},"metadata":2,"items":[1,3],"new":null}"#, status: 201)
        let diff = try await ResponseComparisonService.compare(old, new, ignoring: ["/meta"])
        #expect(Set(diff.map(\.path)) == ["HTTP status", "/value", "/metadata", "/items/1", "/new"])
        let value = try #require(diff.first { $0.path == "/value" })
        #expect(value.before == "\"1\"")
        #expect(value.after == "1")
    }

    @Test func oversizedAndNonJSONResponsesReturnTypedErrors() throws {
        #expect(throws: RequestError.self) { try ResponseJSONService.parse(Data(repeating: 32, count: ResponseJSONService.maxBytes + 1)) }
        #expect(throws: RequestError.self) { try ResponseJSONService.parse(Data("<html>".utf8)) }
    }

    @Test func baselinePersistsIndependentlyOfLatestResponseAndIsDeletedWithSession() throws {
        let requestId = UUID()
        let persistence = SessionPersistenceService.shared
        defer { persistence.deleteSession(for: requestId) }
        let baseline = Self.response(#"{"price":12}"#)
        try persistence.saveBaseline(baseline, for: requestId)
        persistence.saveResponseBody(Data(#"{"price":15}"#.utf8), for: requestId)
        #expect(try persistence.loadBaseline(for: requestId) == baseline)
        persistence.deleteSession(for: requestId)
        #expect(try persistence.loadBaseline(for: requestId) == nil)
    }

    @Test func runnerRejectsMissingFilesInsteadOfSendingEmptyAttachments() throws {
        var data = HttpRequestData()
        data.bodyType = .binary
        data.binaryFileName = "payload.bin"
        let session = HttpSessionStore()
        #expect(throws: RequestError.self) { try HttpWorkflowService.validateAttachments(data, session: session) }
        session.binaryBodyData = Data([1, 2])
        try HttpWorkflowService.validateAttachments(data, session: session)
    }
}
