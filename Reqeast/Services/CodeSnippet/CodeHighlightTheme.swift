// Modified for RHEQ: code snippet color palette.
//
//  CodeHighlightTheme.swift
//  Reqeast
//

import SwiftUI

enum CodeToken {
    case keyword
    case string
    case number
    case comment
    case type
    case plain
}

struct CodeHighlightTheme {
    let colorScheme: ColorScheme

    func color(for token: CodeToken) -> Color {
        let dark = colorScheme == .dark
        switch token {
        case .keyword, .type:
            return dark ? Color(red: 0.57, green: 0.68, blue: 1) : Color(red: 0.18, green: 0.33, blue: 0.73)
        case .string:
            return dark ? Color(red: 0.88, green: 0.69, blue: 0.55) : Color(red: 0.60, green: 0.29, blue: 0.16)
        case .number:
            return dark ? Color(red: 0.56, green: 0.79, blue: 0.68) : Color(red: 0.20, green: 0.43, blue: 0.33)
        case .comment: return .secondary
        case .plain: return .primary
        }
    }
}
