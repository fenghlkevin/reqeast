// Modified for RHEQ: original geometric mark and wordmark replace upstream branding.
import SwiftUI

struct AppLogoView: View {
    var size: CGFloat = 72
    var breathing: Bool = false

    var body: some View {
        RheqLogoShape().fill(.primary)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct AppNameText: View {
    var size: Font = .largeTitle

    var body: some View {
        Text(verbatim: "RHEQ").font(size).fontWeight(.heavy).tracking(1.4).foregroundStyle(.primary)
    }
}
