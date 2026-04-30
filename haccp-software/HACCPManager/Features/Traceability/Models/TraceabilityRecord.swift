import Foundation
import SwiftData

@Model
final class TraceabilityRecord {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var productName: String
    var lotCode: String
    var supplier: String
    var receivedAt: Date
    var expiryDate: Date?
    var createdAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var notes: String?
    var operatorSignature: String?

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        productName: String,
        lotCode: String,
        supplier: String,
        receivedAt: Date,
        expiryDate: Date? = nil,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        notes: String? = nil,
        operatorSignature: String? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.productName = productName
        self.lotCode = lotCode
        self.supplier = supplier
        self.receivedAt = receivedAt
        self.expiryDate = expiryDate
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.notes = notes
        self.operatorSignature = operatorSignature
    }
}
