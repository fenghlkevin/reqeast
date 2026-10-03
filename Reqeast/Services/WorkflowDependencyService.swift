// Original RHEQ workflow dependency analysis.
import Foundation

struct WorkflowDependency: Identifiable {
    var id: String { variable }
    let variable: String
    let source: Request?
    let pointer: String?
    let available: Bool
}

enum WorkflowDependencyService {
    static func dependencies(for request: Request, preceding: [Request], environment: ApiEnvironment?) -> [WorkflowDependency] {
        guard let data = request.httpData else { return [] }
        return RequestVariableService.references(in: data).map { key in
            let source = preceding.last { $0.httpData?.workflow.extractions.contains { $0.enabled && $0.variable == key } == true }
            let rule = source?.httpData?.workflow.extractions.last { $0.enabled && $0.variable == key }
            let variable = environment?.variables.first { $0.key == key && $0.enabled }
            return WorkflowDependency(variable: key, source: source, pointer: rule?.pointer,
                available: source != nil || variable.map { !$0.isSecret || !$0.value.isEmpty } == true)
        }
    }
}
