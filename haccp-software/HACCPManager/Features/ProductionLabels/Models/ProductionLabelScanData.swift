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
        let hasName = !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasDates = productionDate != nil || expiryDate != nil
        let hasLot = !(lotCode?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return hasName || hasDates || hasLot
    }

    static func from(_ label: ProductionLabelRecord, restaurantName: String?) -> ProductionLabelScanData {
        ProductionLabelScanData(
            id: label.id,
            productName: label.productName,
            productionDate: label.productionDate,
            expiryDate: label.expiryDate,
            lotCode: label.lotCode,
            operatorName: label.createdByNameSnapshot,
            supplier: label.supplier,
            category: label.category,
            allergens: label.allergens,
            temperatureNote: label.temperatureNote,
            storageInstructions: label.storageInstructions,
            quantityDisplay: label.quantityDisplay,
            productStatusLabel: label.productStatus.label,
            sourceModuleLabel: label.sourceModule.displayLabel,
            notes: label.notes,
            restaurantName: restaurantName
        )
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
