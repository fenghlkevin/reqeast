import Foundation
import Testing
@testable import Reqeast

@Suite("Saved workflows", .serialized)
@MainActor
struct SavedWorkflowTests {
    @Test func saveReplaceDeleteAndRoundTrip() throws {
        let project = Project(name: "Orders")
        let first = Request(projectId: project.id, name: "Login")
        let second = Request(projectId: project.id, name: "Order")
        let store = ProjectStore.mock(projects: [project], requests: [first, second])
        var plan = SavedHttpWorkflow(name: "Order test", requestIds: [first.id, second.id])
        try store.saveWorkflow(plan, projectId: project.id)
        plan.requestIds.reverse(); plan.stopOnFailure = false
        try store.saveWorkflow(plan, projectId: project.id)
        #expect(store.projects[0].httpWorkflows == [plan])
        let decoded = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(store.projects[0]))
        #expect(decoded.httpWorkflows == [plan])
        try store.removeWorkflow(plan.id, projectId: project.id)
        #expect(store.projects[0].httpWorkflows.isEmpty)
    }
    @Test func oldProjectsDecodeAndInvalidSaveKeepsState() throws {
        let project = Project(name: "Old")
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(project)) as? [String: Any])
        json.removeValue(forKey: "httpWorkflows")
        let decoded = try JSONDecoder().decode(Project.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.httpWorkflows.isEmpty)
        let store = ProjectStore.mock(projects: [project])
        #expect(throws: (any Error).self) { try store.saveWorkflow(SavedHttpWorkflow(name: "", requestIds: []), projectId: project.id) }
        #expect(store.projects == [project])
    }
    @Test func rowsHaveFreshVariablesAndUniqueResultIds() async {
        let project = Project(name: "Rows")
        let request = Request(projectId: project.id, name: "Send")
        let store = ProjectStore.mock(projects: [project], requests: [request])
        store.environments = [ApiEnvironment(projectId: project.id, name: "Test", variables: [EnvironmentVariable(key: "name", value: "original")], isActive: true)]
        var seen: [String] = []
        let runner = HttpRunnerState { request, environment in
            seen.append(environment?.variables.first { $0.key == "name" }?.value ?? "missing")
            return HttpRunResult(requestId: request.id, name: request.name, status: 200, elapsed: 1, checks: [], error: nil)
        }
        runner.start(requests: [request], store: store, stopOnFailure: false,
                     dataset: WorkflowDataset(columns: ["name"], rows: [["name": "a"], ["name": "b"]]))
        await runner.waitUntilFinished()
        #expect(seen == ["a", "b"])
        #expect(store.environments.first?.variables.first?.value == "original")
        #expect(runner.results.map(\.row) == [1, 2])
        #expect(Set(runner.results.map(\.id)).count == 2)
    }
    @Test func deletedEnvironmentDoesNotFallBack() {
        let project = Project(name: "Missing")
        let request = Request(projectId: project.id, name: "Send")
        let store = ProjectStore.mock(projects: [project], requests: [request])
        let runner = HttpRunnerState()
        runner.start(requests: [request], store: store, stopOnFailure: true, environmentId: UUID())
        #expect(!runner.isRunning)
        #expect(runner.results.first?.passed == false)
    }
}
