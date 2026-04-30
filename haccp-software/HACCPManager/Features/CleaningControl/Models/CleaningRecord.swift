import Foundation
import SwiftData

@Model
final class CleaningRecord {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var areaName: String
    var cleaningPlan: String
    var frequency: String
    var completed: Bool
    var createdAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var notes: String?
    var operatorSignature: String?

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        areaName: String,
        cleaningPlan: String,
        frequency: String,
        completed: Bool = false,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        notes: String? = nil,
        operatorSignature: String? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.areaName = areaName
        self.cleaningPlan = cleaningPlan
        self.frequency = frequency
        self.completed = completed
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.notes = notes
        self.operatorSignature = operatorSignature
    }
}
