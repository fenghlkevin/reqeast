// Modified for RHEQ: neutral editor surfaces and restrained, readable syntax colors.
#if os(macOS)
import AppKit
import CodeEditSourceEditor

enum ReqeastEditorTheme {
    static let dark = make(dark: true, response: false)
    static let light = make(dark: false, response: false)
    static let responseDark = make(dark: true, response: true)
    static let responseLight = make(dark: false, response: true)

    private static func color(_ red: Double, _ green: Double, _ blue: Double) -> NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: 1)
    }

    private static func make(dark: Bool, response: Bool) -> EditorTheme {
        let text = dark ? color(0.86, 0.87, 0.90) : color(0.12, 0.13, 0.15)
        let blue = dark ? color(0.57, 0.68, 1.0) : color(0.18, 0.33, 0.73)
        let string = dark ? color(0.88, 0.69, 0.55) : color(0.60, 0.29, 0.16)
        let number = dark ? color(0.56, 0.79, 0.68) : color(0.20, 0.43, 0.33)
        let muted = dark ? color(0.55, 0.57, 0.62) : color(0.45, 0.47, 0.51)
        let background = dark
            ? (response ? color(0.098, 0.102, 0.114) : color(0.133, 0.137, 0.153))
            : (response ? color(0.973, 0.969, 0.957) : color(0.961, 0.957, 0.941))
        return EditorTheme(
            text: .init(color: text),
            insertionPoint: dark ? color(0.45, 0.56, 1.0) : color(0.19, 0.37, 0.96),
            invisibles: .init(color: muted.withAlphaComponent(0.5)),
            background: background,
            lineHighlight: dark ? NSColor.white.withAlphaComponent(0.03) : NSColor.black.withAlphaComponent(0.025),
            selection: blue.withAlphaComponent(dark ? 0.18 : 0.12),
            keywords: .init(color: blue), commands: .init(color: blue), types: .init(color: blue),
            attributes: .init(color: muted), variables: .init(color: blue), values: .init(color: string),
            numbers: .init(color: number), strings: .init(color: string), characters: .init(color: string),
            comments: .init(color: muted)
        )
    }
}
#endif
