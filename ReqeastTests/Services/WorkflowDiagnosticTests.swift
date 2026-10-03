// Original RHEQ dependency, linking and diagnostic regression tests.
import Foundation
import Testing
@testable import Reqeast

@Suite("Workflow and diagnostics", .serialized)
struct WorkflowDiagnosticTests {
    @Test @MainActor func nearestPrecedingProducerWins() {
        let project = Project(name: "Test")
        var first = Request(projectId: project.id, name: "Login", type: .http)
        first.httpData?.workflow.extractions = [ResponseExtraction(pointer: "/token", variable: "token")]
        var second = Request(projectId: project.id, name: "Refresh", type: .http)
        second.httpData?.workflow.extractions = [ResponseExtraction(pointer: "/access", variable: "token")]
        var target = Request(projectId: project.id, name: "Orders", type: .http)
        target.httpData?.headers = [KeyValueEntry(key: "Authorization", value: "Bearer {{token}}")]
        let dependencies = WorkflowDependencyService.dependencies(for: target, preceding: [first, second], environment: nil)
        #expect(dependencies.count == 1)
        #expect(dependencies.first?.source?.id == second.id)
        #expect(dependencies.first?.pointer == "/access")
        #expect(dependencies.first?.available == true)
        #expect(WorkflowDependencyService.dependencies(for: target, preceding: [], environment: nil).first?.available == false)
    }

    @Test @MainActor func linkUpdatesBothRequestsAndPreservesUnrelatedHeaders() throws {
        let project = Project(name: "Test")
        let source = Request(projectId: project.id, name: "Login", type: .http)
        var target = Request(projectId: project.id, name: "Orders", type: .http)
        target.httpData?.headers = [KeyValueEntry(key: "Accept", value: "application/json")]
        target.httpData?.authType = .bearer
        target.httpData?.authToken = "old-token"
        let store = ProjectStore.mock(projects: [project], requests: [source, target])
        try store.linkResponse(sourceId: source.id, targetId: target.id, pointer: "/token", variable: "token", header: "Authorization")
        #expect(store.requests[0].httpData?.workflow.extractions.first?.isSecret == true)
        #expect(store.requests[1].httpData?.authType == HttpAuthType.none)
        #expect(store.requests[1].httpData?.headers.contains { $0.key == "Authorization" && $0.value == "Bearer {{token}}" } == true)
        #expect(store.requests[1].httpData?.headers.contains { $0.key == "Accept" } == true)
        let before = store.requests
        #expect(throws: RequestError.self) {
            try store.linkResponse(sourceId: source.id, targetId: target.id, pointer: "/token", variable: "bad name", header: "Authorization")
        }
        #expect(store.requests == before)
    }

    @Test func redactsEncodedCredentialsAndAllQueryValues() {
        let report = DiagnosticRedactionService.text("failure https://user:password@example.com/path?q=private&token=abc%2Fdef", secrets: ["abc/def"])
        #expect(!report.contains("password"))
        #expect(!report.contains("private"))
        #expect(!report.contains("abc%2Fdef"))
        #expect(report.contains("example.com/path"))
    }

    @Test @MainActor func reportOmitsBodiesAndPreservesErrorChain() {
        let snapshot = HttpDiagnosticSnapshot(timestamp: Date(), preparedRequest: "POST https://example.com/\n\nprivate-body", secrets: ["hidden-token"])
        let error = RequestError(kind: .tlsError, message: "TLS → expired certificate; hidden-token")
        let report = HttpDiagnosticService.report(snapshot: snapshot, response: nil, error: error)
        #expect(report.contains("expired certificate"))
        #expect(!report.contains("hidden-token"))
        #expect(!report.contains("private-body"))
    }
}
