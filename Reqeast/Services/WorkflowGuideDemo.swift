import Foundation

/// Isolated, deterministic examples for manual screenshots. Never sends network requests.
@MainActor
enum WorkflowGuideDemo {
    nonisolated static var isRequested: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-workflowGuideDemo")
            || ProcessInfo.processInfo.environment["REQEAST_GUIDE_DEMO"] == "1"
        #else
        false
        #endif
    }

    static func loadIfRequested(store: ProjectStore) {
        #if DEBUG
        guard isRequested, StorageEnvironment.isScreenshotMode else { return }
        let project = Project(name: "Order API", emoji: "📦")
        var login = Request(projectId: project.id, name: "1 Login", sortOrder: 0)
        login.httpData = HttpRequestData(method: .post, url: "{{baseUrl}}/login", bodyType: .json,
            bodyContent: "{\"username\":\"{{username}}\",\"password\":\"{{password}}\"}")
        login.httpData?.workflow.extractions = [ResponseExtraction(pointer: "/data/token", variable: "token")]
        login.httpData?.workflow.assertions = [ResponseAssertion()]
        var create = Request(projectId: project.id, name: "2 Create order", sortOrder: 1)
        create.httpData = HttpRequestData(method: .post, url: "{{baseUrl}}/orders", bodyType: .json,
            bodyContent: "{\"product\":\"{{product}}\"}", authType: .bearer, authToken: "{{token}}")
        create.httpData?.workflow.extractions = [ResponseExtraction(pointer: "/data/id", variable: "orderId", isSecret: false)]
        create.httpData?.workflow.assertions = [ResponseAssertion(expected: "201")]
        var query = Request(projectId: project.id, name: "3 Query order", sortOrder: 2)
        query.httpData = HttpRequestData(url: "{{baseUrl}}/orders/{{orderId}}", authType: .bearer, authToken: "{{token}}")
        let env = ApiEnvironment(projectId: project.id, name: "Test", variables: [
            EnvironmentVariable(key: "baseUrl", value: "https://api.example.test"),
            EnvironmentVariable(key: "username", value: "demo"),
            EnvironmentVariable(key: "password", value: "demo-only", isSecret: true),
            EnvironmentVariable(key: "product", value: "book"),
            EnvironmentVariable(key: "token", value: "demo-token", isSecret: true),
            EnvironmentVariable(key: "orderId", value: "42")
        ], isActive: true)
        var environment = env
        environment.variables[4].source = ResponseVariableSource(requestId: login.id, requestName: login.name,
            pointer: "/data/token", updatedAt: Date(timeIntervalSince1970: 1_796_256_000))
        var demoProject = project
        demoProject.httpWorkflows = [SavedHttpWorkflow(name: "Order test", requestIds: [login.id, create.id, query.id], environmentId: env.id)]
        store.projects.insert(demoProject, at: 0)
        store.requests += [login, create, query]; store.environments.append(environment)
        let response = HttpResponseData(statusCode: 200, statusText: "OK", headers: [],
            body: Data("{\"data\":{\"token\":\"demo-token\"}}".utf8), elapsedMs: 42, bodySize: 31,
            finalUrl: "https://api.example.test/login", timestamp: Date(), cookies: [], httpVersion: "HTTP/2", remoteAddr: nil)
        SessionRegistry.shared.httpExecution(for: login.id).response = response
        #endif
    }
}
