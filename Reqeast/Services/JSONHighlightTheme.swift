// RHEQ: readable JSON colors shared by request and response views.
import SwiftUI

// MARK: - SwiftUI Theme

struct JSONHighlightTheme {
    let defaultText: Color
    private let colors: [JSONToken: Color]

    init(defaultText: Color, _ colors: [JSONToken: Color]) {
        self.defaultText = defaultText
        self.colors = colors
    }

    func color(for token: JSONToken) -> Color {
        colors[token] ?? defaultText
    }

    static let darkSwiftUI = make(dark: true)
    static let lightSwiftUI = make(dark: false)
    static let responseDarkSwiftUI = darkSwiftUI
    static let responseLightSwiftUI = lightSwiftUI

    private static func make(dark: Bool) -> JSONHighlightTheme {
        let key = dark ? Color(red: 0.57, green: 0.68, blue: 1) : Color(red: 0.18, green: 0.33, blue: 0.73)
        let string = dark ? Color(red: 0.88, green: 0.69, blue: 0.55) : Color(red: 0.60, green: 0.29, blue: 0.16)
        let number = dark ? Color(red: 0.56, green: 0.79, blue: 0.68) : Color(red: 0.20, green: 0.43, blue: 0.33)
        return JSONHighlightTheme(defaultText: .primary, [
            .key: key, .stringValue: string, .numberValue: number,
            .booleanValue: key, .nullValue: key, .punctuation: .secondary
        ])
    }
}
