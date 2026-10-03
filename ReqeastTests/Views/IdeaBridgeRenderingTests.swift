#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import Reqeast

@Suite("IDEA import manual rendering", .serialized,
       .enabled(if: FileManager.default.fileExists(atPath: "/tmp/rheq-render-idea")))
struct IdeaBridgeRenderingTests {
    @Test @MainActor func rendersPreviewWithoutInput() async throws {
        let bytes = try Data(contentsOf: URL(fileURLWithPath: "/tmp/rheq-idea-psi-export.rheqapi"))
        let preview = try await IdeaBridgeImportService.preview(bytes: bytes)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("rheq-idea-manual-images", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for locale in ["en", "zh-Hans", "zh-Hant", "ja", "fr", "pt-BR", "es", "ko", "de"] {
            let content = IdeaBridgeImportSheet(store: .mock(), url: URL(fileURLWithPath: "/tmp/demo.rheqapi"),
                preferredProjectId: nil, onImport: { _ in }, initialPreview: preview)
                .environment(\.locale, Locale(identifier: locale)).environment(\.colorScheme, .light)
                .frame(width: 680, height: 600).background(.white)
            try capture(content, file: directory.appendingPathComponent("manual-\(locale)-idea-import.png"), width: 680, height: 600)
            let settings = Form { IdeaBridgeSettingsSection() }.formStyle(.grouped)
                .environment(\.locale, Locale(identifier: locale)).environment(\.colorScheme, .light)
                .frame(width: 680, height: 240).background(.white)
            let gutter = IdeaGutterManualDiagram().environment(\.locale, Locale(identifier: locale)).environment(\.colorScheme, .light)
            try capture(gutter, file: directory.appendingPathComponent("manual-\(locale)-idea-gutter.png"), width: 850, height: 270)
            try capture(settings, file: directory.appendingPathComponent("manual-\(locale)-idea-install.png"), width: 680, height: 240)

        }
    }
    @MainActor private func capture<V: View>(_ content: V, file: URL, width: CGFloat, height: CGFloat) throws {
        let view = NSHostingView(rootView: content)
        view.frame = NSRect(x: 0, y: 0, width: width, height: height)
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
        try png.write(to: file)
    }

}
#endif
