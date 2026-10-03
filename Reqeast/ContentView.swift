// Modified for RHEQ: workspace appearance.
//
//  ContentView.swift
//  Reqeast
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ProjectManagerView()
            .background(BrandTheme.workspace)
            .modifier(WorkspaceAppearanceModifier())
            #if os(macOS)
            .frame(minWidth: 750, minHeight: 500)
            #endif
    }
}
