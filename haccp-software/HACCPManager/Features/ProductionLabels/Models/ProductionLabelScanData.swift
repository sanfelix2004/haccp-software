import Foundation

/// Dati etichetta estratti dal QR — funzionano su qualsiasi dispositivo, senza archivio locale.
struct ProductionLabelScanData: Identifiable, Equatable {
    let id: UUID
    let productName: String
    let productionDate: Date?
    let expiryDate: Date?
    let lotCode: String?
    let operatorName: String?
    let supplier: String?
    let category: String?
    let allergens: String?
    let temperatureNote: String?
    let storageInstructions: String?
    let quantityDisplay: String?
    let productStatusLabel: String?
    let sourceModuleLabel: String?
    let notes: String?
    let restaurantName: String?

    var allergenList: [String] {
        guard let allergens, !allergens.isEmpty else { return [] }
        return allergens
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var hasRichContent: Bool {
        !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var expiryState: ProductionLabelExpiryState {
        guard let expiryDate else { return .ok }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expiryDay = calendar.startOfDay(for: expiryDate)
        if expiryDay < today { return .expired }
        if let soon = calendar.date(byAdding: .day, value: 3, to: today), expiryDay <= soon {
            return .soon
        }
        return .ok
    }
}
