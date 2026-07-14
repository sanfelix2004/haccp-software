//
//  ModuleNavigationCoordinator.swift
//  Evita fetch SwiftData concorrenti quando si cambia sezione rapidamente.
//

import Foundation
import SwiftUI

private struct SidebarModuleKey: EnvironmentKey {
    static let defaultValue: SidebarItem? = nil
}

extension EnvironmentValues {
    var sidebarModule: SidebarItem? {
        get { self[SidebarModuleKey.self] }
        set { self[SidebarModuleKey.self] = newValue }
    }
}

@MainActor
final class ModuleNavigationCoordinator {
    static let shared = ModuleNavigationCoordinator()

    private(set) var activeModuleId: String?
    private(set) var generation = 0

    private init() {}

    func installActiveModule(_ item: SidebarItem?) {
        activeModuleId = item?.id
    }

    func userSelectedModule(_ item: SidebarItem?) {
        generation += 1
        activeModuleId = item?.id
        ModuleStoreRegistry.shared.cancelAllPendingLoads()
    }

    func isActiveModule(_ moduleId: String) -> Bool {
        activeModuleId == moduleId
    }
}
