import Foundation

struct SavedHttpWorkflow: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var requestIds: [UUID]
    var environmentId: UUID?
    var stopOnFailure = true
}

struct ResponseVariableSource: Codable, Hashable {
    let requestId: UUID?
    let requestName: String
    let pointer: String
    let updatedAt: Date
}

extension ProjectStore {
    func saveWorkflow(_ workflow: SavedHttpWorkflow, projectId: UUID) throws {
        guard let index = projects.firstIndex(where: { $0.id == projectId && $0.deletedAt == nil }),
              !workflow.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !workflow.requestIds.isEmpty else {
            throw ResponseJSONService.failure(String(localized: "Choose requests and enter a workflow name."))
        }
        let previous = projects[index]
        if let i = projects[index].httpWorkflows.firstIndex(where: { $0.id == workflow.id }) {
            projects[index].httpWorkflows[i] = workflow
        } else { projects[index].httpWorkflows.append(workflow) }
        projects[index].touch()
        do { if !isInMemory { try saveLocalOrThrow() } }
        catch { projects[index] = previous; throw error }
        if !isInMemory { CloudSyncService.shared.queueSave(projects[index]) }
    }

    func removeWorkflow(_ id: UUID, projectId: UUID) throws {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else { return }
        let previous = projects[index]
        projects[index].httpWorkflows.removeAll { $0.id == id }
        projects[index].touch()
        do { if !isInMemory { try saveLocalOrThrow() } }
        catch { projects[index] = previous; throw error }
        if !isInMemory { CloudSyncService.shared.queueSave(projects[index]) }
    }
}
