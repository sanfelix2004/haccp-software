import Foundation
import SwiftData

@Model
final class DefrostRecord {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var productName: String
    var method: String
    var startAt: Date
    var endAt: Date?
    var createdAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var notes: String?
    var operatorSignature: String?

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        productName: String,
        method: String,
        startAt: Date,
        endAt: Date? = nil,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        notes: String? = nil,
        operatorSignature: String? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.productName = productName
        self.method = method
        self.startAt = startAt
        self.endAt = endAt
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.notes = notes
        self.operatorSignature = operatorSignature
    }
}
