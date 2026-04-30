import Foundation
import SwiftData

@Model
final class OilControlRecord {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var checkedAt: Date
    var oilState: String
    var indexValue: Double?
    var actionTaken: String
    var createdAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var notes: String?
    var operatorSignature: String?

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        checkedAt: Date,
        oilState: String,
        indexValue: Double? = nil,
        actionTaken: String,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        notes: String? = nil,
        operatorSignature: String? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.checkedAt = checkedAt
        self.oilState = oilState
        self.indexValue = indexValue
        self.actionTaken = actionTaken
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.notes = notes
        self.operatorSignature = operatorSignature
    }
}
