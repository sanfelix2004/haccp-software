import Foundation
import SwiftData

enum CleaningTaskFrequency: String, Codable, CaseIterable {
    case giornaliero
    case settimanale
    case mensile
    case personalizzato

    var label: String {
        switch self {
        case .giornaliero: return "Giornaliero"
        case .settimanale: return "Settimanale"
        case .mensile: return "Mensile"
        case .personalizzato: return "Personalizzato"
        }
    }
}

enum CleaningTaskOutcome: String, Codable, CaseIterable {
    case daFare
    case pulito
    case nonPulito
    case nonApplicabile

    var label: String {
        switch self {
        case .daFare: return "Da fare"
        case .pulito: return "Pulito"
        case .nonPulito: return "Non pulito"
        case .nonApplicabile: return "Non applicabile"
        }
    }
}

@Model
final class CleaningArea {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var name: String
    var createdAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        name: String,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.name = name
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
    }
}

@Model
final class CleaningTask {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var areaId: UUID
    var areaNameSnapshot: String
    var title: String
    var frequencyRaw: String
    /// Solo per frequenza personalizzata.
    var customIntervalDays: Int?
    var isActive: Bool
    var createdAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        areaId: UUID,
        areaNameSnapshot: String,
        title: String,
        frequency: CleaningTaskFrequency,
        customIntervalDays: Int? = nil,
        isActive: Bool = true,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.areaId = areaId
        self.areaNameSnapshot = areaNameSnapshot
        self.title = title
        self.frequencyRaw = frequency.rawValue
        self.customIntervalDays = customIntervalDays
        self.isActive = isActive
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
    }

    var frequency: CleaningTaskFrequency {
        get { CleaningTaskFrequency(rawValue: frequencyRaw) ?? .giornaliero }
        set { frequencyRaw = newValue.rawValue }
    }
}

@Model
final class CleaningRecord {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var areaId: UUID
    var areaName: String
    var taskId: UUID
    var taskName: String
    var frequencyRaw: String
    var periodStart: Date
    var periodEnd: Date
    var outcomeRaw: String
    var completed: Bool
    var createdAt: Date
    var updatedAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var updatedByUserId: UUID
    var updatedByNameSnapshot: String
    var notes: String?
    var correctiveAction: String?
    var operatorSignature: String?
    var isArchived: Bool = false
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        areaId: UUID,
        areaName: String,
        taskId: UUID,
        taskName: String,
        frequency: CleaningTaskFrequency,
        periodStart: Date,
        periodEnd: Date,
        outcome: CleaningTaskOutcome = .daFare,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        updatedByUserId: UUID,
        updatedByNameSnapshot: String,
        notes: String? = nil,
        correctiveAction: String? = nil,
        operatorSignature: String? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.areaId = areaId
        self.areaName = areaName
        self.taskId = taskId
        self.taskName = taskName
        self.frequencyRaw = frequency.rawValue
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.outcomeRaw = outcome.rawValue
        self.completed = outcome != .daFare
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.updatedByUserId = updatedByUserId
        self.updatedByNameSnapshot = updatedByNameSnapshot
        self.notes = notes
        self.correctiveAction = correctiveAction
        self.operatorSignature = operatorSignature
    }

    var outcome: CleaningTaskOutcome {
        get { CleaningTaskOutcome(rawValue: outcomeRaw) ?? .daFare }
        set {
            outcomeRaw = newValue.rawValue
            completed = newValue != .daFare
        }
    }

    var frequency: CleaningTaskFrequency {
        get { CleaningTaskFrequency(rawValue: frequencyRaw) ?? .giornaliero }
        set { frequencyRaw = newValue.rawValue }
    }
}

@Model
final class CleaningCriticality {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var recordId: UUID
    var areaName: String
    var taskName: String
    var note: String
    var correctiveAction: String
    var isResolved: Bool
    var createdAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var resolvedAt: Date?
    var resolvedByUserId: UUID?
    var resolvedByNameSnapshot: String?

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        recordId: UUID,
        areaName: String,
        taskName: String,
        note: String,
        correctiveAction: String,
        isResolved: Bool = false,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        resolvedAt: Date? = nil,
        resolvedByUserId: UUID? = nil,
        resolvedByNameSnapshot: String? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.recordId = recordId
        self.areaName = areaName
        self.taskName = taskName
        self.note = note
        self.correctiveAction = correctiveAction
        self.isResolved = isResolved
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.resolvedAt = resolvedAt
        self.resolvedByUserId = resolvedByUserId
        self.resolvedByNameSnapshot = resolvedByNameSnapshot
    }
}
