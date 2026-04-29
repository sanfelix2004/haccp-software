import Foundation
import SwiftData

@Model
final class ChecklistAlert {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var checklistRunId: UUID
    var severityRaw: String
    var message: String
    var statusRaw: String = ChecklistAlertStatus.active.rawValue
    var createdAt: Date
    var resolvedAt: Date?
    var resolvedByUserId: UUID?
    var resolvedByName: String?
    var correctiveAction: String?
    var isActive: Bool

    var severity: ChecklistAlertSeverity {
        get { ChecklistAlertSeverity(rawValue: severityRaw) ?? .warning }
        set { severityRaw = newValue.rawValue }
    }

    var status: ChecklistAlertStatus {
        get { ChecklistAlertStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        checklistRunId: UUID,
        severity: ChecklistAlertSeverity,
        message: String,
        status: ChecklistAlertStatus = .active,
        createdAt: Date = Date(),
        resolvedAt: Date? = nil,
        resolvedByUserId: UUID? = nil,
        resolvedByName: String? = nil,
        correctiveAction: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.checklistRunId = checklistRunId
        self.severityRaw = severity.rawValue
        self.message = message
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
        self.resolvedByUserId = resolvedByUserId
        self.resolvedByName = resolvedByName
        self.correctiveAction = correctiveAction
        self.isActive = isActive
    }
}
