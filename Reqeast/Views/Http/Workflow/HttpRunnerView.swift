// Modified for RHEQ: visual workflows and HTTP diagnostics.
import SwiftUI

struct HttpRunnerView: View {
    @Bindable var store: ProjectStore
    let projectId: UUID
    let folderId: UUID?
    @Bindable var runner: HttpRunnerState
    @State private var selected: Set<UUID> = []
    @State private var order: [UUID] = []
    @State private var selectedFolder: UUID?
    @State private var stopOnFailure = true
    @State private var planId: UUID?
    @State private var name = ""
    @State private var environmentId: UUID?
    @State private var dataset: WorkflowDataset?
    @State private var error: RequestError?

    private var requests: [Request] { store.requests(for: projectId).filter { $0.type == .http && $0.httpData != nil } }
    private var plans: [SavedHttpWorkflow] { store.projects.first { $0.id == projectId }?.httpWorkflows ?? [] }
    private var visible: [Request] {
        let byId = Dictionary(uniqueKeysWithValues: requests.map { ($0.id, $0) })
        return order.compactMap { byId[$0] }.filter { selectedFolder == nil || $0.folderId == selectedFolder }
    }

    var body: some View {
        let positions = Dictionary(uniqueKeysWithValues: visible.filter { selected.contains($0.id) }
            .enumerated().map { ($0.element.id, $0.offset + 1) })
        Form {
            Section("Saved Workflows") {
                Picker("Workflow", selection: $planId) {
                    Text("New Workflow").tag(nil as UUID?)
                    ForEach(plans) { Text($0.name).tag(Optional($0.id)) }
                }.tint(.primary).accessibilityIdentifier("saved-workflow-picker")
                TextField("Workflow Name", text: $name).devTextInput().accessibilityIdentifier("workflow-name")
                Picker("Environment", selection: $environmentId) {
                    Text("Active Environment").tag(nil as UUID?)
                    ForEach(store.environments.filter { $0.projectId == projectId && $0.deletedAt == nil }) {
                        Text($0.name).tag(Optional($0.id))
                    }
                }.tint(.primary)
                HStack {
                    Button("Save Workflow") {
                        do {
                            var plan = SavedHttpWorkflow(name: name, requestIds: visible.filter { selected.contains($0.id) }.map(\.id),
                                environmentId: environmentId, stopOnFailure: stopOnFailure)
                            if let planId { plan.id = planId }
                            try store.saveWorkflow(plan, projectId: projectId); planId = plan.id
                        } catch { self.error = RequestError.from(error) }
                    }.buttonStyle(.glass).accessibilityIdentifier("save-workflow")
                    if let planId {
                        Button("Delete Workflow", role: .destructive) {
                            do { try store.removeWorkflow(planId, projectId: projectId); self.planId = nil }
                            catch { self.error = RequestError.from(error) }
                        }
                    }
                }
            }.disabled(runner.isRunning || store.isSpecProjectReadOnly(projectId: projectId))
            Section("Execution Order") {
                Text("Requests run one at a time in the order below. Extracted variables are available to the next request.")
                Picker("Folder", selection: $selectedFolder) {
                    Text("All HTTP Requests").tag(nil as UUID?)
                    ForEach(store.requestFolders(for: projectId)) { Text($0.name).tag(Optional($0.id)) }
                }.tint(.primary).disabled(runner.isRunning)
                WorkflowSequenceView(requests: visible.filter { selected.contains($0.id) },
                    environment: environmentId.flatMap { id in store.environments.first { $0.id == id && $0.deletedAt == nil } }
                        ?? store.activeEnvironment(for: projectId), runner: runner, store: store)
                DisclosureGroup("Choose & Reorder Requests") {
                    ForEach(visible) { request in
                        HttpRunnerRequestRow(request: request, position: positions[request.id], selected: $selected,
                                             move: { move(request.id, by: $0) })
                    }.disabled(runner.isRunning)
                }
                Toggle("Stop on first failure", isOn: $stopOnFailure).disabled(runner.isRunning)
                if let plan = plans.first(where: { $0.id == planId }), !Set(plan.requestIds).isSubset(of: Set(requests.map(\.id))) {
                    Text("A saved request was removed. Update this workflow before running.").foregroundStyle(.red).textSelection(.enabled)
                }
            }
            WorkflowDatasetView(dataset: $dataset).disabled(runner.isRunning)
            Section {
                if let error { Text(error.message).foregroundStyle(.red).textSelection(.enabled) }
                Text("Run sends real requests, including POST and DELETE. Review the selected requests and active environment first.")
                    .font(.caption).foregroundStyle(.secondary)
                if runner.isRunning {
                    Label(runner.activeName, systemImage: "paperplane")
                    Button("Stop Run", role: .destructive) { runner.stop() }.buttonStyle(.glass)
                } else {
                    Button("Run Selected Requests") {
                        runner.start(requests: visible.filter { selected.contains($0.id) }, store: store,
                                     stopOnFailure: stopOnFailure, environmentId: environmentId, dataset: dataset)
                    }.buttonStyle(.glassProminent).accessibilityIdentifier("run-workflow")
                    .disabled(!visible.contains { selected.contains($0.id) } || store.isSpecProjectReadOnly(projectId: projectId)
                        || plans.first(where: { $0.id == planId }).map { !Set($0.requestIds).isSubset(of: Set(requests.map(\.id))) } == true)
                }
                if runner.stopped { Text("Run stopped. A request already sent may still complete on the server.").font(.caption) }
            }
            HttpRunResultsView(runner: runner)
        }.formStyle(.grouped).accessibilityIdentifier("workflow-runner-form")
        .onAppear {
            if order.isEmpty {
                order = requests.map(\.id); selected = Set(order); selectedFolder = folderId
                if let first = plans.first { planId = first.id; loadPlan() }
                #if DEBUG
                if WorkflowGuideDemo.isRequested, StorageEnvironment.isScreenshotMode {
                    dataset = WorkflowDataset(columns: ["username", "password", "product"], rows: [
                        ["username": "demo-a", "password": "test-a", "product": "book"],
                        ["username": "demo-b", "password": "test-b", "product": "pen"]])
                    runner.results = (1...2).flatMap { row in
                        requests.prefix(3).enumerated().map { index, request in
                            let status = index == 1 ? 201 : 200
                            return HttpRunResult(requestId: request.id, row: row, name: request.name, status: status,
                                elapsed: 42, checks: [WorkflowCheck(label: String(localized: "Status code equals"),
                                    passed: true, detail: "\(status) → \(status)")], error: nil)
                        }
                    }
                }
                #endif
            }
        }
        .onChange(of: planId) { loadPlan() }
        .onDisappear { runner.stop() }
    }

    private func loadPlan() {
        guard let plan = plans.first(where: { $0.id == planId }) else { name = ""; return }
        name = plan.name; selected = Set(plan.requestIds); selectedFolder = nil
        order = plan.requestIds + requests.map(\.id).filter { !selected.contains($0) }
        environmentId = plan.environmentId; stopOnFailure = plan.stopOnFailure
    }

    private func move(_ id: UUID, by offset: Int) {
        let ids = visible.map(\.id)
        guard let index = ids.firstIndex(of: id), ids.indices.contains(index + offset),
              let source = order.firstIndex(of: id), let target = order.firstIndex(of: ids[index + offset]) else { return }
        order.swapAt(source, target)
    }
}
