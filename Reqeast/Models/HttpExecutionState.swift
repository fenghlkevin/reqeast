// Modified for RHEQ: visual workflows and HTTP diagnostics.
//
//  HttpExecutionState.swift
//  Reqeast
//

import Foundation

@MainActor
@Observable
class HttpExecutionState {
    var isLoading = false
    var response: HttpResponseData?
    var error: RequestError?
    var diagnostic: HttpDiagnosticSnapshot?
    var workflowError: RequestError?
    var workflowChecks: [WorkflowCheck] = []

    let httpService = HttpService.shared
    private var currentTask: Task<Void, Never>?

    func send(
        request: Request,
        environment: ApiEnvironment?,
        sessionStore: HttpSessionStore,
        store: ProjectStore = .shared,
        onAutoRename: (@Sendable (String) -> Void)? = nil
    ) {
        guard let httpData = request.httpData else { return }
        cancel()
        isLoading = true
        error = nil
        response = nil
        workflowError = nil
        workflowChecks = []
        diagnostic = nil

        currentTask = Task {
            await performSend(
                request: request,
                httpData: httpData,
                environment: environment,
                sessionStore: sessionStore,
                store: store,
                onAutoRename: onAutoRename
            )
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
    }

    func clear() {
        response = nil
        error = nil
        workflowError = nil
        workflowChecks = []
        diagnostic = nil
    }

    /// Shared send path for the runner, including cookies, history, extraction and assertions.
    func run(request: Request, environment: ApiEnvironment?, sessionStore: HttpSessionStore,
             store: ProjectStore) async {
        send(request: request, environment: environment, sessionStore: sessionStore, store: store)
        await currentTask?.value
    }

}
