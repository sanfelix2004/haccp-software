import Foundation
import SwiftData

@Model
final class ProductionLabelRecord {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var productName: String
    var productionDate: Date
    var expiryDate: Date
    var lotCode: String?
    var previewText: String?
    var createdAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var notes: String?
    var operatorSignature: String?
    var isArchived: Bool = false
    var archivedAt: Date?

    // Estensione enterprise HACCP
    var category: String?
    var supplier: String?
    var allergens: String?
    var storageInstructions: String?
    var temperatureNote: String?
    var quantity: Double?
    var unit: String?
    var productStatusRaw: String = ProductionLabelProductStatus.ready.rawValue
    var sourceModuleRaw: String = ProductionLabelSource.manual.rawValue
    var traceabilityRecordId: UUID?
    var goodsReceiptId: UUID?
    var blastChillingRecordId: UUID?
    var defrostRecordId: UUID?
    var productionId: UUID?
    var qrPayload: String = ""
    var statusRaw: String = ProductionLabelStatus.active.rawValue
    var updatedAt: Date = Date()
    var duplicateOfLabelId: UUID?
    var reprintCount: Int = 0

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        productName: String,
        productionDate: Date,
        expiryDate: Date,
        lotCode: String? = nil,
        previewText: String? = nil,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        notes: String? = nil,
        operatorSignature: String? = nil,
        category: String? = nil,
        supplier: String? = nil,
        allergens: String? = nil,
        storageInstructions: String? = nil,
        temperatureNote: String? = nil,
        quantity: Double? = nil,
        unit: String? = nil,
        productStatus: ProductionLabelProductStatus = .ready,
        sourceModule: ProductionLabelSource = .manual,
        traceabilityRecordId: UUID? = nil,
        goodsReceiptId: UUID? = nil,
        blastChillingRecordId: UUID? = nil,
        defrostRecordId: UUID? = nil,
        productionId: UUID? = nil,
        qrPayload: String = "",
        status: ProductionLabelStatus = .active,
        updatedAt: Date = Date(),
        duplicateOfLabelId: UUID? = nil,
        reprintCount: Int = 0
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.productName = productName
        self.productionDate = productionDate
        self.expiryDate = expiryDate
        self.lotCode = lotCode
        self.previewText = previewText
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.notes = notes
        self.operatorSignature = operatorSignature
        self.category = category
        self.supplier = supplier
        self.allergens = allergens
        self.storageInstructions = storageInstructions
        self.temperatureNote = temperatureNote
        self.quantity = quantity
        self.unit = unit
        self.productStatusRaw = productStatus.rawValue
        self.sourceModuleRaw = sourceModule.rawValue
        self.traceabilityRecordId = traceabilityRecordId
        self.goodsReceiptId = goodsReceiptId
        self.blastChillingRecordId = blastChillingRecordId
        self.defrostRecordId = defrostRecordId
        self.productionId = productionId
        self.qrPayload = qrPayload
        self.statusRaw = status.rawValue
        self.updatedAt = updatedAt
        self.duplicateOfLabelId = duplicateOfLabelId
        self.reprintCount = reprintCount
    }
}

extension ProductionLabelRecord {
    var sourceModule: ProductionLabelSource {
        get { ProductionLabelSource(rawValue: sourceModuleRaw) ?? .manual }
        set { sourceModuleRaw = newValue.rawValue }
    }

    var labelStatus: ProductionLabelStatus {
        get { ProductionLabelStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var productStatus: ProductionLabelProductStatus {
        get { ProductionLabelProductStatus(rawValue: productStatusRaw) ?? .ready }
        set { productStatusRaw = newValue.rawValue }
    }

    var allergenList: [String] {
        guard let allergens, !allergens.isEmpty else { return [] }
        return allergens
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var expiryState: ProductionLabelExpiryState {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expiryDay = calendar.startOfDay(for: expiryDate)
        if expiryDay < today { return .expired }
        if let soon = calendar.date(byAdding: .day, value: 3, to: today), expiryDay <= soon {
            return .soon
        }
        return .ok
    }

    var quantityDisplay: String? {
        guard let quantity else { return nil }
        let formatted = quantity.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", quantity)
            : String(format: "%.2f", quantity)
        if let unit, !unit.isEmpty { return "\(formatted) \(unit)" }
        return formatted
    }
}

/// Bozza editor (non persistita fino al salvataggio).
struct ProductionLabelDraft: Equatable {
    var productName: String = ""
    var category: String = ""
    var lotCode: String = ""
    var supplier: String = ""
    var productionDate: Date = Date()
    var expiryDate: Date = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    var allergens: String = ""
    var storageInstructions: String = "Frigo +2°C / +4°C"
    var temperatureNote: String = ""
    var quantity: String = ""
    var unit: String = "pz"
    var notes: String = ""
    var productStatus: ProductionLabelProductStatus = .ready
    var sourceModule: ProductionLabelSource = .manual
    var traceabilityRecordId: UUID?
    var goodsReceiptId: UUID?
    var blastChillingRecordId: UUID?
    var defrostRecordId: UUID?
    var productionId: UUID?

    var isValid: Bool {
        !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && expiryDate >= productionDate
    }
}
