import Foundation

extension ProjectStore {
    func commitCodeImport(_ plan: CodeImportPlan) throws -> Project {
        guard !importInProgress, !syncApplyInProgress else {
            throw RequestError(kind: .invalidConfig, message: String(localized: "Another import is in progress."))
        }
        if !plan.isNewProject {
            guard let current = projects.first(where: { $0.id == plan.project.id && $0.deletedAt == nil }), current.specLink == nil else {
                throw BulkImportError.projectNotFound(id: plan.project.id)
            }
        }
        guard plan.isNewProject || !plan.requests.isEmpty else { return plan.project }
        var project = plan.project
        var changed = plan.requests
        if plan.isNewProject { project.touch(); try validateCodeRecord(project) }
        for index in changed.indices { changed[index].touch(); try validateCodeRecord(changed[index]) }
        let previousProjects = projects
        let previousRequests = requests
        importInProgress = true
        defer { importInProgress = false }
        do {
            if plan.isNewProject { projects.append(project) }
            for request in changed {
                if let index = requests.firstIndex(where: { $0.id == request.id }) { requests[index] = request }
                else { requests.append(request) }
            }
            if isInMemory {
                #if DEBUG
                bulkImportSaveLocalCallCount += 1
                if bulkImportSaveLocalShouldFail { throw BulkImportError.localPersistFailed }
                #endif
            } else {
                try saveLocalOrThrow()
            }
        } catch {
            projects = previousProjects
            requests = previousRequests
            throw error
        }
        if !isInMemory {
            CloudSyncService.shared.queueSaveBatch(project: plan.isNewProject ? project : nil, requests: changed)
            #if os(macOS)
            MCPExportService.shared.exportProjects(store: self)
            #endif
        }
        return project
    }

    private func validateCodeRecord<T: CloudSyncable>(_ record: T) throws {
        let bytes = try JSONEncoder().encode(record)
        guard bytes.count <= CloudSyncService.maxRecordPayloadBytes else {
            throw BulkImportError.recordTooLarge(recordType: T.syncRecordType, id: record.id, byteCount: bytes.count)
        }
    }
}
