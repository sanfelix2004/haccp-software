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
        operatorSignature: String? = nil
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
    }
}
