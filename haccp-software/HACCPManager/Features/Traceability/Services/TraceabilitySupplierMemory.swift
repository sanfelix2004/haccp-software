import Foundation

/// Ricorda l’ultimo fornitore scelto in Tracciabilità (stesso catalogo di Ricezione merci).
enum TraceabilitySupplierMemory {
    private static func key(restaurantId: UUID) -> String {
        "traceability.lastSupplierId.\(restaurantId.uuidString)"
    }

    static func lastUsedId(for restaurantId: UUID) -> UUID? {
        guard let raw = UserDefaults.standard.string(forKey: key(restaurantId: restaurantId)),
              let id = UUID(uuidString: raw) else { return nil }
        return id
    }

    static func remember(id: UUID, restaurantId: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: key(restaurantId: restaurantId))
    }

    static func clear(restaurantId: UUID) {
        UserDefaults.standard.removeObject(forKey: key(restaurantId: restaurantId))
    }
}
