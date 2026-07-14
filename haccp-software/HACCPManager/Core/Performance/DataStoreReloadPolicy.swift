//
//  DataStoreReloadPolicy.swift
//  Evita fetch ridondanti quando i dati sono già caldi per il ristorante attivo.
//

import Foundation

@MainActor
struct DataStoreReloadPolicy {
    private(set) var lastRestaurantId: UUID?
    private(set) var lastLoadedAt: Date?

    /// Intervallo minimo tra reload automatici dello stesso ristorante (notifiche, revisit).
    var minimumReloadInterval: TimeInterval = 45

    mutating func shouldReload(
        restaurantId: UUID?,
        hasData: Bool,
        force: Bool = false
    ) -> Bool {
        guard let restaurantId else { return false }
        if force { return true }
        if lastRestaurantId != restaurantId { return true }
        if !hasData { return true }
        guard let lastLoadedAt else { return true }
        return Date().timeIntervalSince(lastLoadedAt) >= minimumReloadInterval
    }

    mutating func markLoaded(restaurantId: UUID) {
        lastRestaurantId = restaurantId
        lastLoadedAt = Date()
    }

    mutating func invalidate() {
        lastRestaurantId = nil
        lastLoadedAt = nil
    }
}
