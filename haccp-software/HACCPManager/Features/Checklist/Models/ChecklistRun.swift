import Foundation
import SwiftData

@Model
final class ChecklistRun {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var templateId: UUID
    var templateTitleSnapshot: String
    var startedAt: Date
    var completedAt: Date?
    var dueAt: Date?
    var statusRaw: String
    var completedByUserId: UUID?
    var completedByNameSnapshot: String?
    var progressPercentage: Double
    var notes: String?
    var isArchived: Bool
    var createdAt: Date

    var status: ChecklistRunStatus {
        get { ChecklistRunStatus(rawValue: statusRaw) ?? .notStarted }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        templateId: UUID,
        templateTitleSnapshot: String,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        dueAt: Date? = nil,
        status: ChecklistRunStatus = .notStarted,
        completedByUserId: UUID? = nil,
        completedByNameSnapshot: String? = nil,
        progressPercentage: Double = 0,
        notes: String? = nil,
        isArchived: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.templateId = templateId
        self.templateTitleSnapshot = templateTitleSnapshot
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.dueAt = dueAt
        self.statusRaw = status.rawValue
        self.completedByUserId = completedByUserId
        self.completedByNameSnapshot = completedByNameSnapshot
        self.progressPercentage = progressPercentage
        self.notes = notes
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}
