import Foundation
import SwiftData

@Model
final class GoodsReceivingRecord {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var supplierId: UUID?
    var supplierNameSnapshot: String = ""
    var productTemplateId: UUID?
    var productNameSnapshot: String = ""
    var categoryRaw: String = GoodsCategory.all.rawValue
    var receivedAt: Date = Date()
    var temperatureValue: Double?
    var minAllowed: Double?
    var maxAllowed: Double?
    var temperatureStatusRaw: String = GoodsReceiptStatus.conforme.rawValue
    var lotNumber: String?
    var expiryDate: Date?
    var productionDate: Date?
    var quantity: Double?
    var unit: String?
    var checklistResultsData: Data?
    var photoData: Data?
    var notes: String?
    var correctiveAction: String?
    var statusRaw: String = GoodsReceiptStatus.conforme.rawValue
    var createdAt: Date = Date()
    var createdByUserId: UUID?
    var createdByNameSnapshot: String = ""

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        supplierId: UUID?,
        supplierNameSnapshot: String,
        productTemplateId: UUID?,
        productNameSnapshot: String,
        category: GoodsCategory,
        receivedAt: Date,
        temperatureValue: Double? = nil,
        minAllowed: Double? = nil,
        maxAllowed: Double? = nil,
        temperatureStatus: GoodsReceiptStatus = .conforme,
        lotNumber: String? = nil,
        expiryDate: Date? = nil,
        productionDate: Date? = nil,
        quantity: Double? = nil,
        unit: String? = nil,
        checklistResultsData: Data? = nil,
        photoData: Data? = nil,
        notes: String? = nil,
        correctiveAction: String? = nil,
        status: GoodsReceiptStatus,
        createdAt: Date = Date(),
        createdByUserId: UUID?,
        createdByNameSnapshot: String
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.supplierId = supplierId
        self.supplierNameSnapshot = supplierNameSnapshot
        self.productTemplateId = productTemplateId
        self.productNameSnapshot = productNameSnapshot
        self.categoryRaw = category.rawValue
        self.receivedAt = receivedAt
        self.temperatureValue = temperatureValue
        self.minAllowed = minAllowed
        self.maxAllowed = maxAllowed
        self.temperatureStatusRaw = temperatureStatus.rawValue
        self.lotNumber = lotNumber
        self.expiryDate = expiryDate
        self.productionDate = productionDate
        self.quantity = quantity
        self.unit = unit
        self.checklistResultsData = checklistResultsData
        self.photoData = photoData
        self.notes = notes
        self.correctiveAction = correctiveAction
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
    }

    var category: GoodsCategory {
        get { GoodsCategory(rawValue: categoryRaw) ?? .all }
        set { categoryRaw = newValue.rawValue }
    }

    var checklistResults: [GoodsReceiptChecklistResult] {
        get {
            guard let checklistResultsData else { return [] }
            return (try? JSONDecoder().decode([GoodsReceiptChecklistResult].self, from: checklistResultsData)) ?? []
        }
        set { checklistResultsData = try? JSONEncoder().encode(newValue) }
    }

    var status: GoodsReceiptStatus {
        get { GoodsReceiptStatus(rawValue: statusRaw) ?? .conforme }
        set { statusRaw = newValue.rawValue }
    }

    var temperatureStatus: GoodsReceiptStatus {
        get { GoodsReceiptStatus(rawValue: temperatureStatusRaw) ?? .conforme }
        set { temperatureStatusRaw = newValue.rawValue }
    }
}

typealias GoodsReceipt = GoodsReceivingRecord
