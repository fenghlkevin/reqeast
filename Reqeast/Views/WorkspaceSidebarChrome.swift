// RHEQ: brand header and fixed navigation actions. Native sidebar selection is preserved.
import SwiftUI

struct WorkspaceSidebarChrome: ViewModifier {
    var request: Request? = nil
    @State private var showingManual = false
    @State private var showingWorkflow = false
    @State private var showingHistory = false

    func body(content: Content) -> some View {
        #if os(macOS)
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                AppLogoView(size: 24)
                AppNameText(size: .system(size: 15))
                Spacer()
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
            .fixedSize(horizontal: false, vertical: true)

            content
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            navigationActions
                .fixedSize(horizontal: false, vertical: true)
        }
        .background(BrandTheme.sidebar)
            .sheet(isPresented: $showingManual) { HttpWorkflowGuide(initialTopic: 0) }
            .sheet(isPresented: $showingWorkflow) {
                if let request { HttpWorkflowSheet(store: .shared, requestId: request.id) }
            }
            .sheet(isPresented: $showingHistory) {
                if let request {
                    HttpHistoryPopover(
                        history: SessionRegistry.shared.httpSession(for: request.id).history,
                        onRestore: { data in
                            // Resolve the live record so restoring history preserves any newer edits.
                            guard var updated = ProjectStore.shared.requests.first(where: {
                                $0.id == request.id && $0.deletedAt == nil
                            }) else { return }
                            updated.httpData = data
                            updated.updatedAt = Date()
                            ProjectStore.shared.updateRequest(updated)
                            showingHistory = false
                        },
                        onDismiss: { showingHistory = false }
                    )
                }
            }
        #else
        content
        #endif
    }

    #if os(macOS)
    private var navigationActions: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().padding(.bottom, 6)
            if request?.type == .http {
                Button { showingWorkflow = true } label: { Label("HTTP Workflows", systemImage: "flowchart") }
                Button { showingHistory = true } label: { Label("History", systemImage: "clock.arrow.circlepath") }
            }
            Button { showingManual = true } label: { Label("User Manual", systemImage: "book") }
            SettingsLink { Label("Settings", systemImage: "gearshape") }
        }
        .buttonStyle(.plain)
        .font(.subheadline)
        .foregroundStyle(.primary)
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 18).padding(.bottom, 14)
    }
    #endif
}
