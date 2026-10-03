import SwiftUI

struct HttpWorkflowSheet: View {
    @Bindable var store: ProjectStore
    let requestId: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var tab = 0
    @State private var showingGuide = false
    @State private var runner = HttpRunnerState()

    private var request: Request? { store.requests.first { $0.id == requestId && $0.deletedAt == nil } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("HTTP Workflows").font(.title2.bold())
                Spacer()
                Button { showingGuide = true } label: { Label("Illustrated Guide", systemImage: "book") }
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("workflow-guide")
            }.padding()
            Divider()
            Group {
                if sizeClass == .compact { topicPicker.pickerStyle(.menu) }
                else { topicPicker.pickerStyle(.segmented) }
            }.tint(.primary).padding().disabled(runner.isRunning)
            if let request {
                Group {
                    switch tab {
                    case 1: HttpComparisonView(requestId: requestId)
                    case 3: HttpRequestInspectionView(store: store, request: request)
                    case 4: PortableProjectView(store: store, projectId: request.projectId)
                    case 2: HttpRunnerView(store: store, projectId: request.projectId, folderId: request.folderId, runner: runner)
                    default: HttpWorkflowRulesView(store: store, requestId: requestId)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            HStack {
                Button("Close") { dismiss() }.accessibilityIdentifier("workflow-close").keyboardShortcut(.cancelAction).buttonStyle(.glass)
                Spacer()
                Text("Rules are saved automatically.").font(.caption).foregroundStyle(.secondary)
            }.padding()
        }
        #if os(macOS)
        .frame(width: 900, height: 780)
        #endif
        .sheet(isPresented: $showingGuide) { HttpWorkflowGuide(initialTopic: tab) }
    }

    private var topicPicker: some View {
        Picker("Workflow", selection: $tab) {
            Text("Variables & Checks").tag(0)
            Text("Compare Responses").tag(1).accessibilityIdentifier("workflow-comparison-tab")
            Text("Run Requests").tag(2).accessibilityIdentifier("workflow-runner-tab")
            Text("Inspect Request").tag(3).accessibilityIdentifier("workflow-inspect-tab")
            Text("Project Files").tag(4).accessibilityIdentifier("workflow-files-tab")
        }
    }
}
