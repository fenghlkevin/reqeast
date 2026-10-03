// Modified for RHEQ: visual workflows and HTTP diagnostics.
import Foundation

struct HttpRunResult: Identifiable {
    let id = UUID()
    let requestId: UUID
    var row: Int = 1
    let name: String
    let status: Int?
    let elapsed: Double?
    let checks: [WorkflowCheck]
    let error: RequestError?
    var passed: Bool { error == nil && status.map { (200..<300).contains($0) } == true && checks.allSatisfy(\.passed) }
}

@MainActor
@Observable
final class HttpRunnerState {
    var isRunning = false
    var stopped = false
    var activeName = ""
    var activeRequestId: UUID?
    var results: [HttpRunResult] = []
    private var task: Task<Void, Never>?
    private var execution: HttpExecutionState?
    typealias Executor = @MainActor (Request, ApiEnvironment?) async -> HttpRunResult
    private let executor: Executor?

    init(executor: Executor? = nil) { self.executor = executor }

    func waitUntilFinished() async { await task?.value }

    func start(requests: [Request], store: ProjectStore, stopOnFailure: Bool, environmentId: UUID? = nil, dataset: WorkflowDataset? = nil) {
        guard !isRunning, !requests.isEmpty else { return }
        if let environmentId, !store.environments.contains(where: { $0.id == environmentId && $0.deletedAt == nil }) {
            results = [HttpRunResult(requestId: requests[0].id, name: requests[0].name, status: nil, elapsed: nil,
                checks: [], error: ResponseJSONService.failure(String(localized: "The selected environment no longer exists.")))]
            return
        }
        results = []
        stopped = false
        isRunning = true
        let environment = environmentId.flatMap { id in store.environments.first { $0.id == id && $0.deletedAt == nil } }
            ?? store.activeEnvironment(for: requests[0].projectId)
        task = Task {
            defer { isRunning = false; activeName = ""; activeRequestId = nil; execution = nil }
            let rows = dataset?.rows ?? [[:]]
            for (rowIndex, values) in rows.enumerated() {
                let runStore: ProjectStore
                if dataset != nil {
                    runStore = ProjectStore.mock(projects: store.projects, requests: store.requests)
                    var isolated = environment ?? ApiEnvironment(projectId: requests[0].projectId, name: "Run", isActive: true)
                    for (key, value) in values {
                        isolated.variables.removeAll { $0.key == key }
                        isolated.variables.append(EnvironmentVariable(key: key, value: value, isSecret: true))
                    }
                    runStore.environments = [isolated]
                } else { runStore = store }
                for request in requests {
                    guard !Task.isCancelled else { break }
                    activeName = request.name
                    activeRequestId = request.id
                    if let executor {
                        let latest = runStore.environments.first(where: { $0.id == environment?.id || environment == nil && dataset != nil }) ?? environment.flatMap { captured in
                            runStore.environments.first { $0.id == captured.id && $0.deletedAt == nil }
                        }
                        var result = await executor(request, latest)
                        result.row = rowIndex + 1
                        guard !Task.isCancelled else { break }
                        results.append(result)
                        if stopOnFailure && !result.passed { break }
                        continue
                    }
                    let state = SessionRegistry.shared.httpExecution(for: request.id)
                    if state.isLoading {
                        results.append(HttpRunResult(requestId: request.id, row: rowIndex + 1, name: request.name, status: nil, elapsed: nil,
                            checks: [], error: ResponseJSONService.failure(String(localized: "This request is already running."))))
                        if stopOnFailure { break }
                        continue
                    }
                    execution = state
                    let session = SessionRegistry.shared.httpSession(for: request.id)
                    session.loadHistoryIfNeeded(for: request.id)
                    do {
                        if let data = request.httpData { try HttpWorkflowService.validateAttachments(data, session: session) }
                    } catch {
                        results.append(HttpRunResult(requestId: request.id, row: rowIndex + 1, name: request.name, status: nil, elapsed: nil,
                                                     checks: [], error: RequestError.from(error)))
                        if stopOnFailure { break }
                        continue
                    }
                    let latestEnvironment = runStore.environments.first(where: { $0.id == environment?.id || environment == nil && dataset != nil }) ?? environment.flatMap { captured in
                        runStore.environments.first { $0.id == captured.id && $0.deletedAt == nil }
                    }
                    var resolvedRequest = request
                    if let rules = request.httpData?.workflow.assertions {
                        resolvedRequest.httpData?.workflow.assertions = rules.map { rule in
                            var copy = rule
                            copy.expected = EnvironmentVariableService.substitute(rule.expected, environment: latestEnvironment)
                            return copy
                        }
                    }
                    await state.run(request: resolvedRequest, environment: latestEnvironment, sessionStore: session, store: runStore)
                    guard !Task.isCancelled else { break }
                    var result = HttpRunResult(requestId: request.id, name: request.name, status: state.response?.statusCode,
                        elapsed: state.response?.elapsedMs, checks: state.workflowChecks, error: state.error ?? state.workflowError)
                    result.row = rowIndex + 1
                    results.append(result)
                    if stopOnFailure && !result.passed { break }
                }
                if Task.isCancelled || stopOnFailure && results.last?.passed == false { break }
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        stopped = true
        task?.cancel()
        execution?.cancel()
        // Keep the runner busy until the in-flight synchronous network call returns.
    }
}
