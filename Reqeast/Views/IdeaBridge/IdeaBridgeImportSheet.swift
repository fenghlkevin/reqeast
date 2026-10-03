import SwiftUI

struct IdeaBridgeImportSheet: View {
    var store: ProjectStore
    var url: URL
    var preferredProjectId: UUID?
    var onImport: (Project) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var preview: IdeaBridgePreview?
    @State private var targetId: UUID?
    @State private var selected = Set<String>()
    @State private var baseURL = ""
    @State private var error: RequestError?
    @State private var loading = true
    @State private var showingManual = false

    init(store: ProjectStore, url: URL, preferredProjectId: UUID?, onImport: @escaping (Project) -> Void,
         initialPreview: IdeaBridgePreview? = nil) {
        self.store = store
        self.url = url
        self.preferredProjectId = preferredProjectId
        self.onImport = onImport
        _targetId = State(initialValue: preferredProjectId)
        _preview = State(initialValue: initialPreview)
        _loading = State(initialValue: initialPreview == nil)
        _baseURL = State(initialValue: initialPreview?.descriptor.baseURL ?? "")
        _selected = State(initialValue: Set(initialPreview?.spec.mapped.requests.compactMap { $0.specIdentity?.primaryKey } ?? []))
    }

    private var targets: [Project] { store.projects.filter { $0.deletedAt == nil && $0.specLink == nil } }
    private var target: Project? { targets.first { $0.id == targetId } }
    private var plan: CodeImportPlan? {
        guard let preview else { return nil }
        return try? CodeImportMerge.plan(preview: preview, target: target, existing: store.requests, selected: selected, baseURL: baseURL)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Import from IDEA").font(.headline)
                Spacer()
                Button("User Manual", systemImage: "book.closed") { showingManual = true }.buttonStyle(.glass)
            }.padding()
            Divider()
            if loading { ProgressView().frame(maxWidth: .infinity, minHeight: 240) }
            else if let preview {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Target Project", selection: $targetId) {
                            Text("New Project").tag(nil as UUID?)
                            ForEach(targets) { Text($0.name).tag(Optional($0.id)) }
                        }.tint(.primary)
                        TextField("Base URL", text: $baseURL).devTextInput().textFieldStyle(.roundedBorder)
                        Text("Matching interfaces are refreshed. Your credentials, test values, and workflow links are preserved. Missing interfaces are retained.")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button("Select All") { selected = Set(preview.spec.mapped.requests.compactMap { $0.specIdentity?.primaryKey }) }
                            Button("Select None") { selected.removeAll() }
                            Spacer()
                            if let plan { Text(verbatim: "+\(plan.addedCount) / ↻\(plan.updatedCount)").monospacedDigit() }
                        }.buttonStyle(.glass)
                        ForEach(preview.spec.mapped.requests) { request in
                            if let identity = request.specIdentity?.primaryKey, let http = request.httpData {
                                Toggle(isOn: Binding(get: { selected.contains(identity) }, set: { value in
                                    if value { selected.insert(identity) } else { selected.remove(identity) }
                                })) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(request.name).font(.subheadline.bold())
                                        Text(verbatim: "\(http.method.rawLabel) \(http.url.replacingOccurrences(of: "{{base_url}}", with: baseURL))")
                                            .font(.caption.monospaced()).textSelection(.enabled)
                                    }
                                }
                                Divider()
                            }
                        }
                        ForEach(Array((preview.descriptor.warnings + preview.spec.warnings.map(\.message)).enumerated()), id: \.offset) { _, warning in
                            Text(warning).font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                        }
                    }.padding()
                }
            }
            if let error { Text(error.message).foregroundStyle(.red).textSelection(.enabled).padding() }
            Divider()
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.glass)
                Spacer()
                Button("Import") { commit() }.buttonStyle(.glassProminent).disabled(loading || selected.isEmpty || plan == nil)
            }.padding()
        }
        #if os(macOS)
        .frame(width: 680, height: 600)
        #endif
        .task { if preview == nil { await load() } }
        .sheet(isPresented: $showingManual) { HttpWorkflowGuide(initialTopic: 5) }
    }

    private func load() async {
        do {
            let bytes = try await IdeaBridgeImportService.read(url)
            let result = try await IdeaBridgeImportService.preview(bytes: bytes)
            preview = result
            baseURL = result.descriptor.baseURL
            selected = Set(result.spec.mapped.requests.compactMap { $0.specIdentity?.primaryKey })
            let linkedProject = store.requests.first { $0.deletedAt == nil && $0.codeImport?.sourceId == result.descriptor.sourceId }?.projectId
            targetId = targets.first { $0.id == linkedProject }?.id ?? targets.first { $0.id == preferredProjectId }?.id
        } catch { self.error = RequestError.from(error) }
        loading = false
    }

    private func commit() {
        guard let preview else { return }
        do {
            let plan = try CodeImportMerge.plan(preview: preview, target: target, existing: store.requests, selected: selected, baseURL: baseURL)
            let project = try store.commitCodeImport(plan)
            onImport(project)
            dismiss()
        } catch { self.error = RequestError.from(error) }
    }
}
