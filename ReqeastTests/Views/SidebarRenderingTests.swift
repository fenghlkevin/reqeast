#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import Reqeast

@Suite("Sidebar layout rendering", .serialized,
       .enabled(if: FileManager.default.fileExists(atPath: "/tmp/rheq-render-sidebar")))
struct SidebarRenderingTests {
    @Test @MainActor func longRequestListStaysWithinChrome() throws {
        let project = Project(name: "Controller")
        let requests = (0..<50).map { index in
            var request = Request(projectId: project.id, name: "接口 \(index)", type: .http, sortOrder: index)
            request.httpData?.url = "http://localhost:8080/api/items/\(index)"
            return request
        }
        let store = ProjectStore.mock(projects: [project], requests: requests)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("rheq-sidebar-layout", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for height: CGFloat in [460, 760] {
            let content = RequestListView(store: store, project: project, selectedRequestId: .constant(requests[0].id))
                .environment(\.locale, Locale(identifier: "zh-Hans"))
                .environment(\.colorScheme, .light)
                .frame(width: 290, height: height)
            let view = NSHostingView(rootView: content)
            view.frame = NSRect(x: 0, y: 0, width: 290, height: height)
            let window = NSWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .aqua)
            window.contentView = view
            defer { window.close() }
            view.layoutSubtreeIfNeeded()
            let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            #expect(png.count > 5000)
            try png.write(to: directory.appendingPathComponent("sidebar-\(Int(height)).png"))
        }
    }
}
#endif
