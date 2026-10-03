import Foundation
import Testing
@testable import Reqeast

@Suite("Request inspection", .serialized)
@MainActor
struct RequestInspectionTests {
    @Test func disabledFieldsAndInactiveAuthAreNotRequired() {
        let data = HttpRequestData(url: "{{baseUrl}}/orders", headers: [KeyValueEntry(key: "X", value: "{{disabled}}", enabled: false)], authToken: "{{inactive}}")
        #expect(RequestVariableService.references(in: data) == ["baseUrl"])
    }
    @Test func missingSecretAndPreviewUsesRealPreparation() {
        let environment = ApiEnvironment(projectId: UUID(), name: "Test", variables: [
            EnvironmentVariable(key: "baseUrl", value: "https://example.test"),
            EnvironmentVariable(key: "token", value: "secret-token", isSecret: true)])
        let data = HttpRequestData(method: .post, url: "{{baseUrl}}/orders", params: [KeyValueEntry(key: "id", value: "42")],
            bodyType: .json, bodyContent: "{\"token\":\"{{token}}\"}", authType: .bearer, authToken: "{{token}}")
        let config = HttpSendPreparation.config(data: data, environment: environment, sessionStore: HttpSessionStore())
        let visible = RequestPreviewService.text(config, environment: environment, hideSecrets: false)
        #expect(visible.contains("https://example.test/orders?id=42"))
        #expect(visible.contains("Bearer secret-token"))
        let hidden = RequestPreviewService.text(config, environment: environment, hideSecrets: true)
        #expect(!hidden.contains("secret-token"))
        var empty = environment; empty.variables[1].value = ""
        #expect(RequestVariableService.missing(in: data, environment: empty) == ["token"])
    }
}
