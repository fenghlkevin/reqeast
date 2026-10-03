import Foundation

extension ProjectStore {
    func saveResponseVariables(_ values: [(ResponseExtraction, String)], environmentId: UUID, source: ResponseVariableSource? = nil) throws {
        guard let index = environments.firstIndex(where: { $0.id == environmentId && $0.deletedAt == nil }) else {
            throw ResponseJSONService.failure(String(localized: "The selected environment no longer exists."))
        }
        let previous = environments[index]
        var updated = previous
        for (rule, value) in values {
            if let i = updated.variables.firstIndex(where: { $0.key == rule.variable }) {
                updated.variables[i].value = value
                updated.variables[i].enabled = true
                updated.variables[i].source = source.map { ResponseVariableSource(requestId: $0.requestId, requestName: $0.requestName, pointer: rule.pointer, updatedAt: $0.updatedAt) }
                updated.variables[i].isSecret = updated.variables[i].isSecret || rule.isSecret
            } else {
                var variable = EnvironmentVariable(key: rule.variable, value: value, isSecret: rule.isSecret)
                variable.source = source.map { ResponseVariableSource(requestId: $0.requestId, requestName: $0.requestName, pointer: rule.pointer, updatedAt: $0.updatedAt) }
                updated.variables.append(variable)
            }
        }
        guard updated.variables != previous.variables else { return }
        updated.touch()
        environments[index] = updated
        do { if !isInMemory { try saveLocalOrThrow() } } catch {
            environments[index] = previous
            throw error
        }
        if !isInMemory { CloudSyncService.shared.queueSave(updated) }
    }
}
