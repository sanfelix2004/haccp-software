import Foundation
import SwiftData

enum SchedulingFrequency: String, Codable, CaseIterable {
    case daily = "GIORNALIERA"
    case weekly = "SETTIMANALE"
    case monthly = "MENSILE"
    case custom = "PERSONALIZZATA"
}

@Model
final class ScheduledTask {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var title: String
    var taskDescription: String
    var frequencyRaw: String
    var dueAt: Date?
    var isCompleted: Bool
    var createdAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var notes: String?
    var operatorSignature: String?

    var frequency: SchedulingFrequency {
        get { SchedulingFrequency(rawValue: frequencyRaw) ?? .custom }
        set { frequencyRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        title: String,
        taskDescription: String,
        frequency: SchedulingFrequency,
        dueAt: Date? = nil,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        notes: String? = nil,
        operatorSignature: String? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.title = title
        self.taskDescription = taskDescription
        self.frequencyRaw = frequency.rawValue
        self.dueAt = dueAt
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.notes = notes
        self.operatorSignature = operatorSignature
    }
}
