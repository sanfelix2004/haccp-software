//
//  RestaurantModuleBootstrap.swift
//  Bootstrap per ristorante eseguito una sola volta per sessione (ensureDefaults, seed, migrate).
//

import Foundation

@MainActor
final class RestaurantModuleBootstrap {
    static let shared = RestaurantModuleBootstrap()

    private var completedKeys = Set<String>()

    private init() {}

    @discardableResult
    func claimOnce(restaurantId: UUID, module: String) -> Bool {
        let key = "\(restaurantId.uuidString):\(module)"
        return completedKeys.insert(key).inserted
    }

    @discardableResult
    func runOnce(restaurantId: UUID, module: String, action: () -> Void) -> Bool {
        guard claimOnce(restaurantId: restaurantId, module: module) else { return false }
        action()
        return true
    }

    func invalidate(restaurantId: UUID) {
        let prefix = "\(restaurantId.uuidString):"
        completedKeys = completedKeys.filter { !$0.hasPrefix(prefix) }
    }

    func invalidateAll() {
        completedKeys.removeAll()
    }
}
