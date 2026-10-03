#if os(macOS)
import AppKit
import SwiftUI
import ScreenCaptureKit
import Testing
@testable import Reqeast

@Suite("RHEQ offscreen rendering", .serialized,
       .enabled(if: FileManager.default.fileExists(atPath: "/tmp/rheq-render-preview")))
struct RheqRenderingTests {
    @Test @MainActor func rendersLightAndDarkWorkspaceWithoutInput() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("rheq-preview", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let project = Project(name: "订单服务", emoji: "")
        let users = RequestFolder(projectId: project.id, name: "用户", color: .gray)
        let orders = RequestFolder(projectId: project.id, name: "订单", color: .gray)
        var login = Request(projectId: project.id, name: "登录", folderId: users.id, sortOrder: 0)
        login.httpData = HttpRequestData(method: .post, url: "{{baseUrl}}/login")
        var create = Request(projectId: project.id, name: "创建订单", folderId: orders.id, sortOrder: 1)
        create.httpData = HttpRequestData(method: .post, url: "{{baseUrl}}/orders")
        var query = Request(projectId: project.id, name: "查询订单", folderId: orders.id, sortOrder: 2)
        query.httpData = HttpRequestData(url: "{{baseUrl}}/orders/{{orderId}}",
                                        params: [KeyValueEntry(key: "include", value: "items")])
        let store = ProjectStore.mock(projects: [project], requests: [login, create, query], requestFolders: [users, orders])
        let responseBody = Data("{\n  \"data\": {\n    \"id\": \"ORD-1024\",\n    \"status\": \"created\",\n    \"total\": 128.00\n  }\n}".utf8)
        SessionRegistry.shared.httpExecution(for: query.id).response = HttpResponseData(
            statusCode: 200, statusText: "OK", headers: [KeyValueEntry(key: "Content-Type", value: "application/json")],
            body: responseBody, elapsedMs: 128, bodySize: Int64(responseBody.count),
            finalUrl: "https://api.example.test/orders/ORD-1024", timestamp: Date(), cookies: [], httpVersion: "HTTP/2", remoteAddr: nil
        )
        store.environments = [ApiEnvironment(projectId: project.id, name: "测试环境", variables: [
            EnvironmentVariable(key: "baseUrl", value: "https://api.example.test"),
            EnvironmentVariable(key: "orderId", value: "ORD-1024")
        ], isActive: true)]
        let originalTab = UIStateStore.shared.globalResponseTab
        let originalMode = UIStateStore.shared.globalResponseViewMode
        defer {
            UIStateStore.shared.globalResponseTab = originalTab
            UIStateStore.shared.globalResponseViewMode = originalMode
            SessionRegistry.shared.httpExecution(for: query.id).clear()
        }
        UIStateStore.shared.globalResponseTab = .body
        UIStateStore.shared.globalResponseViewMode = .pretty
        UIStateStore.shared.setSplitRatio(0.42, for: query.id)
        for dark in [false, true] {
            let content = NavigationSplitView {
                RequestListView(store: store, project: project, selectedRequestId: .constant(query.id))
                    .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
            } detail: {
                RequestEditorView(store: store, requestId: query.id)
                    .navigationTitle(query.name)
            }
            .navigationSplitViewStyle(.balanced)
            .tint(BrandTheme.action)
            .environment(\.locale, Locale(identifier: "zh-Hans"))
            .environment(\.colorScheme, dark ? .dark : .light)
            .preferredColorScheme(dark ? .dark : .light)
            .frame(width: 1160, height: 780)
            .background(BrandTheme.workspace)
            let window = NSWindow(
                contentRect: NSRect(x: 80, y: 80, width: 1160, height: 780),
                styleMask: [.titled, .closable], backing: .buffered, defer: false
            )
            window.isReleasedWhenClosed = false
            window.title = "RHEQ"
            window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            window.contentView = NSHostingView(rootView: content)
            // Behind existing windows; never make key, activate, or synthesize an input event.
            window.orderBack(nil)
            defer { window.close() }
            try await Task.sleep(for: .milliseconds(1200))
            let ownContent = try await SCShareableContent.currentProcess
            let ownWindow = try #require(ownContent.windows.first { $0.windowID == CGWindowID(window.windowNumber) })
            let filter = SCContentFilter(desktopIndependentWindow: ownWindow)
            let configuration = SCStreamConfiguration()
            configuration.width = 2320
            configuration.height = 1604
            configuration.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            let bitmap = NSBitmapImageRep(cgImage: image)
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            #expect(image.width == 2320)
            #expect(png.count > 10_000)
            try png.write(to: directory.appendingPathComponent(dark ? "rheq-dark.png" : "rheq-light.png"))
        }
    }
}
#endif
