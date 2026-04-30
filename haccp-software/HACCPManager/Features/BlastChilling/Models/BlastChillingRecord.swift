import Foundation
import SwiftData

@Model
final class BlastChillingRecord {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var productName: String
    var initialTemperature: Double
    var finalTemperature: Double
    var startAt: Date
    var endAt: Date?
    var outcome: String
    var createdAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var notes: String?
    var operatorSignature: String?

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        productName: String,
        initialTemperature: Double,
        finalTemperature: Double,
        startAt: Date,
        endAt: Date? = nil,
        outcome: String,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        notes: String? = nil,
        operatorSignature: String? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.productName = productName
        self.initialTemperature = initialTemperature
        self.finalTemperature = finalTemperature
        self.startAt = startAt
        self.endAt = endAt
        self.outcome = outcome
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.notes = notes
        self.operatorSignature = operatorSignature
    }
}
