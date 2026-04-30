import Foundation
import SwiftData

@Model
final class GoodsReceivingRecord {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var productName: String
    var supplier: String
    var receivedAt: Date
    var packageState: String
    var measuredTemperature: Double?
    var compliant: Bool
    var createdAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var notes: String?
    var operatorSignature: String?

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        productName: String,
        supplier: String,
        receivedAt: Date,
        packageState: String,
        measuredTemperature: Double? = nil,
        compliant: Bool,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        notes: String? = nil,
        operatorSignature: String? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.productName = productName
        self.supplier = supplier
        self.receivedAt = receivedAt
        self.packageState = packageState
        self.measuredTemperature = measuredTemperature
        self.compliant = compliant
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.notes = notes
        self.operatorSignature = operatorSignature
    }
}
