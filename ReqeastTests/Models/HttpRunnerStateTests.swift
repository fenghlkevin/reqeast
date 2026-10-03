import Foundation
import Testing
@testable import Reqeast

@Suite("HTTP runner", .serialized)
@MainActor
struct HttpRunnerStateTests {
    @Test func sequentialExecutionRefreshesVariablesAndStopsOnFailure() async {
        let project = Project(name: "Runner")
        let first = Request(projectId: project.id, name: "Login")
        let second = Request(projectId: project.id, name: "Order")
        let third = Request(projectId: project.id, name: "Skipped")
        let environment = ApiEnvironment(projectId: project.id, name: "Test", isActive: true)
        let store = ProjectStore.mock(projects: [project], requests: [first, second, third])
        store.environments = [environment]
        var seen: [UUID] = []
        let runner = HttpRunnerState { request, current in
            seen.append(request.id)
            if request.id == first.id {
                try? store.saveResponseVariables([(ResponseExtraction(), "demo")], environmentId: environment.id)
            } else {
                #expect(current?.variables.first?.value == "demo")
            }
            return HttpRunResult(requestId: request.id, name: request.name, status: request.id == second.id ? 500 : 200,
                elapsed: 10, checks: [], error: nil)
        }
        runner.start(requests: [first, second, third], store: store, stopOnFailure: true)
        await runner.waitUntilFinished()
        #expect(seen == [first.id, second.id])
        #expect(runner.results.count == 2)
        #expect(!runner.isRunning)
    }

    @Test func continueOnFailureStillRunsRemainingRequests() async {
        let project = Project(name: "Runner")
        let first = Request(projectId: project.id, name: "First")
        let second = Request(projectId: project.id, name: "Second")
        let store = ProjectStore.mock(projects: [project], requests: [first, second])
        let runner = HttpRunnerState { request, _ in
            HttpRunResult(requestId: request.id, name: request.name, status: 404, elapsed: 10, checks: [], error: nil)
        }
        runner.start(requests: [first, second], store: store, stopOnFailure: false)
        await runner.waitUntilFinished()
        #expect(runner.results.map(\.requestId) == [first.id, second.id])
        #expect(runner.results.allSatisfy { !$0.passed })
    }

    @Test func cancellationDoesNotSendLaterRequests() async {
        let project = Project(name: "Runner")
        let requests = [Request(projectId: project.id, name: "First"), Request(projectId: project.id, name: "Second")]
        let store = ProjectStore.mock(projects: [project], requests: requests)
        var seen: [UUID] = []
        var runner: HttpRunnerState!
        runner = HttpRunnerState { request, _ in
            seen.append(request.id)
            runner.stop()
            return HttpRunResult(requestId: request.id, name: request.name, status: 200, elapsed: 10, checks: [], error: nil)
        }
        runner.start(requests: requests, store: store, stopOnFailure: false)
        await runner.waitUntilFinished()
        #expect(seen == [requests[0].id])
        #expect(runner.results.isEmpty)
        #expect(runner.stopped)
    }
}
