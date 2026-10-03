// Modified for RHEQ: neutral surfaces and cobalt actions.
//
//  BrandTheme.swift
//  Reqeast
//

import SwiftUI

enum BrandTheme {
    static let brand = Color.primary
    static let brandDark = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let brandLight = Color(red: 0.94, green: 0.94, blue: 0.92)
    static let action = Color("AccentColor")
    static let workspace = Color("WorkspaceBackground")
    static let sidebar = Color("SidebarBackground")
    static let panel = Color("PanelBackground")

    // MARK: - Animation Curves

    static let springSnappy = Animation.spring(duration: 0.3, bounce: 0.2)
    static let springGentle = Animation.spring(duration: 0.5, bounce: 0.15)
    static let easeQuick = Animation.easeInOut(duration: 0.15)
}
