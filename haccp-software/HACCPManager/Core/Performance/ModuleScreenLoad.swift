//
//  ModuleScreenLoad.swift
//  Caricamento moduli: cede il main thread e attende navigazione stabile.
//

import SwiftUI

extension View {
    /// Pattern standard moduli HACCP — carica solo il modulo sidebar attivo.
    func moduleScreenLoad(
        restaurantId: UUID?,
        action: @escaping @MainActor () async -> Void
    ) -> some View {
        modifier(ModuleScreenLoadModifier(restaurantId: restaurantId, action: action))
    }
}

private struct ModuleScreenLoadModifier: ViewModifier {
    @Environment(\.sidebarModule) private var sidebarModule

    let restaurantId: UUID?
    let action: @MainActor () async -> Void

    private var taskId: String {
        "\(sidebarModule?.id ?? "none")-\(restaurantId?.uuidString ?? "none")"
    }

    func body(content: Content) -> some View {
        content.task(id: taskId, priority: .utility) {
            guard let restaurantId, let module = sidebarModule else { return }
            let moduleId = module.id

            await MainThreadYield.afterNavigation()
            guard !Task.isCancelled,
                  ModuleNavigationCoordinator.shared.isActiveModule(moduleId) else { return }

            await MainThreadYield.awaitNavigationSettled {
                ModuleNavigationCoordinator.shared.generation
            }
            guard !Task.isCancelled,
                  ModuleNavigationCoordinator.shared.isActiveModule(moduleId) else { return }

            await action()
        }
    }
}
