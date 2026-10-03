// Modified for RHEQ: visual workflows and HTTP diagnostics.
import Foundation

@MainActor
enum HttpWorkflowService {
    static func validateAttachments(_ data: HttpRequestData, session: HttpSessionStore) throws {
        let missingBinary = data.bodyType == .binary && !data.binaryFileName.isEmpty && session.binaryBodyData == nil
        let missingFormFile = data.bodyType == .formData && data.bodyFormDataEntries.contains {
            $0.enabled && !$0.key.isEmpty && $0.fieldType == .file && session.formDataFiles[$0.id] == nil
        }
        if missingBinary || missingFormFile {
            throw ResponseJSONService.failure(String(localized: "Attach the request files again before running."))
        }
    }

    static func checks(_ rules: [ResponseAssertion], response: HttpResponseData) -> [WorkflowCheck] {
        rules.filter(\.enabled).map { rule in
            do {
                let actual: String
                let passed: Bool
                switch rule.kind {
                case .status:
                    actual = String(response.statusCode)
                    passed = Int(rule.expected) == response.statusCode
                case .elapsed:
                    actual = String(format: "%.0f", response.elapsedMs)
                    passed = Double(rule.expected).map { $0 > 0 && response.elapsedMs < $0 } ?? false
                case .jsonValue:
                    let value = try ResponseJSONService.value(at: rule.pointer, in: ResponseJSONService.parse(response.body))
                    actual = try ResponseJSONService.text(value)
                    passed = actual == rule.expected
                }
                return WorkflowCheck(label: rule.kind.localizedName, passed: passed,
                                     detail: rule.pointer + " · " + String(localized: "Actual") + ": " + actual + " · " + String(localized: "Expected") + ": " + rule.expected)
            } catch {
                return WorkflowCheck(label: rule.kind.localizedName, passed: false, detail: error.localizedDescription)
            }
        }
    }

    /// Stage every extraction first. A missing field leaves all existing variables untouched.
    static func extract(_ rules: [ResponseExtraction], response: HttpResponseData,
                        environment: ApiEnvironment?, store: ProjectStore, request: Request? = nil) throws {
        let enabled = rules.filter(\.enabled)
        guard !enabled.isEmpty else { return }
        guard let environment else {
            throw ResponseJSONService.failure(String(localized: "Select an environment before saving response variables."))
        }
        let document = try ResponseJSONService.parse(response.body)
        var values: [(ResponseExtraction, String)] = []
        var keys: Set<String> = []
        for rule in enabled {
            let key = rule.variable.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !key.contains("{"), !key.contains("}"), keys.insert(key).inserted else {
                throw ResponseJSONService.failure(String(localized: "Use unique, nonempty variable names without braces."))
            }
            let value = try ResponseJSONService.value(at: rule.pointer, in: document)
            guard !(value is NSNull) else {
                throw ResponseJSONService.failure(String(localized: "The selected field is null. Existing variables were kept."))
            }
            var normalized = rule
            normalized.variable = key
            values.append((normalized, try ResponseJSONService.text(value)))
        }
        try store.saveResponseVariables(values, environmentId: environment.id, source:
            ResponseVariableSource(requestId: request?.id, requestName: request?.name ?? String(localized: "Current Response"),
                                   pointer: "", updatedAt: Date()))
    }
}
