//
//  SidebarModuleHost.swift
//  Un solo modulo attivo per frame — niente ZStack di moduli nascosti con @Query attive.
//

import SwiftUI

struct ActiveModuleDetailLayer<Content: View>: View {
    let selectedItem: SidebarItem
    @ViewBuilder var content: (SidebarItem) -> Content

    var body: some View {
        content(selectedItem)
            .transition(.identity)
    }
}
