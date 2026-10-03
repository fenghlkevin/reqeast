// Modified for RHEQ: visual workflows and HTTP diagnostics.
import Foundation

extension HttpExecutionState {
    // MARK: - Private

    func performSend(
        request: Request,
        httpData: HttpRequestData,
        environment: ApiEnvironment?,
        sessionStore: HttpSessionStore,
        store: ProjectStore,
        onAutoRename: (@Sendable (String) -> Void)?
    ) async {
        let missing = RequestVariableService.missing(in: httpData, environment: environment)
        guard missing.isEmpty else {
            isLoading = false
            error = ResponseJSONService.failure(String(localized: "Define the missing variables before sending.") + " " + missing.joined(separator: ", "))
            return
        }
        let config = HttpSendPreparation.config(data: httpData, environment: environment, sessionStore: sessionStore)
        diagnostic = HttpDiagnosticService.snapshot(config: config, data: httpData, environment: environment)
        let started = ContinuousClock.now
        let result = await httpService.sendPrepared(config)
        let elapsed = started.duration(to: .now).components
        diagnostic?.durationMs = Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15

        guard !Task.isCancelled else { return }

        isLoading = false
        if !store.isInMemory, let index = store.requests.firstIndex(where: { $0.id == request.id }) {
            store.requests[index].touch()
            store.saveAll()
            CloudSyncService.shared.queueSave(store.requests[index])
        } else if !store.isInMemory {
            store.saveAll()
        }

        switch result {
        case .success(let httpResponse):
            response = httpResponse
            workflowChecks = HttpWorkflowService.checks(httpData.workflow.assertions, response: httpResponse)
            if (200..<300).contains(httpResponse.statusCode) {
                do {
                    try HttpWorkflowService.extract(httpData.workflow.extractions, response: httpResponse,
                                                    environment: environment, store: store, request: request)
                } catch { workflowError = RequestError.from(error) }
            }
            if !httpResponse.cookies.isEmpty {
                CookieStore.shared.addCookiesFromResponse(httpResponse.cookies)
            }
            let entry = RequestHistoryEntry(
                requestId: request.id,
                method: httpData.method.rawLabel,
                url: httpData.url,
                statusCode: httpResponse.statusCode,
                elapsedMs: httpResponse.elapsedMs,
                bodySize: httpResponse.bodySize,
                httpData: httpData
            )
            sessionStore.history.append(entry)
            SessionPersistenceService.shared.saveResponseBody(httpResponse.body, for: request.id)
            SessionPersistenceService.shared.saveHistory(sessionStore.history, for: request.id)

            #if os(macOS)
            let projectName = store.projects.first { $0.id == request.projectId }?.name ?? ""
            MCPExportService.shared.recordExecution(
                requestId: request.id,
                requestName: request.name,
                projectName: projectName,
                method: httpData.method.rawLabel,
                url: httpData.url,
                statusCode: httpResponse.statusCode,
                elapsedMs: httpResponse.elapsedMs
            )
            MCPExportService.shared.exportResponseMeta(requestId: request.id, response: httpResponse)
            #endif

            if !request.isRenamed, let onAutoRename {
                let method = httpData.method.rawLabel
                let url = httpData.url
                let statusCode = httpResponse.statusCode
                Task {
                    if let name = await RequestNamingService.generateName(
                        method: method, url: url, statusCode: statusCode
                    ) {
                        onAutoRename(name)
                    }
                }
            }
        case .failure(let err):
            response = nil
            error = RequestError.from(err)

            #if os(macOS)
            let projectName = store.projects.first { $0.id == request.projectId }?.name ?? ""
            MCPExportService.shared.recordExecution(
                requestId: request.id,
                requestName: request.name,
                projectName: projectName,
                method: httpData.method.rawLabel,
                url: httpData.url,
                statusCode: 0,
                elapsedMs: 0
            )
            #endif
        }
    }
}
