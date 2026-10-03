// RHEQ: follow system appearance by default, with explicit light and dark options.
import SwiftUI

enum WorkspaceAppearance: String, CaseIterable {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var localizedName: String {
        switch self {
        case .system: String(localized: "Follow System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }
}

struct WorkspaceAppearanceModifier: ViewModifier {
    @AppStorage("rheqAppearance") private var appearance: WorkspaceAppearance = .system

    func body(content: Content) -> some View {
        content.preferredColorScheme(appearance.colorScheme).tint(BrandTheme.action)
    }
}
