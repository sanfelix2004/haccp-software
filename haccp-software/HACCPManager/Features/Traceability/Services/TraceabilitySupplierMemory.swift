import Foundation

/// Ricorda l'ultimo fornitore usato per accelerare la registrazione lotti.
enum TraceabilitySupplierMemory {
    private static func key(restaurantId: UUID) -> String {
        "traceability.lastSupplier.\(restaurantId.uuidString)"
    }

    static func lastUsed(for restaurantId: UUID) -> String? {
        let value = UserDefaults.standard.string(forKey: key(restaurantId: restaurantId))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    static func remember(_ supplier: String, restaurantId: UUID) {
        let trimmed = supplier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UserDefaults.standard.set(trimmed, forKey: key(restaurantId: restaurantId))
    }
}
