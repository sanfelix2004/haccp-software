import Foundation

/// Contratto unificato per criticità (checklist, pulizie, futuri moduli).
protocol HACCPCriticalityRecord {
    var id: UUID { get }
    var restaurantId: UUID { get }
    var title: String { get }
    var message: String { get }
    var createdAt: Date { get }
    var isResolved: Bool { get }
    var correctiveAction: String? { get }
    var areaTag: String? { get }
    var sourceModule: String { get }
}

struct ChecklistAlertCriticalityAdapter: HACCPCriticalityRecord {
    let alert: ChecklistAlert

    var id: UUID { alert.id }
    var restaurantId: UUID { alert.restaurantId }
    var title: String { "Checklist" }
    var message: String { alert.message }
    var createdAt: Date { alert.createdAt }
    var isResolved: Bool { !alert.isActive }
    var correctiveAction: String? { alert.correctiveAction }
    var areaTag: String? { nil }
    var sourceModule: String { "checklist" }
}

struct CleaningCriticalityAdapter: HACCPCriticalityRecord {
    let criticality: CleaningCriticality

    var id: UUID { criticality.id }
    var restaurantId: UUID { criticality.restaurantId }
    var title: String { criticality.areaName }
    var message: String { "\(criticality.taskName) · \(criticality.note)" }
    var createdAt: Date { criticality.createdAt }
    var isResolved: Bool { criticality.isResolved }
    var correctiveAction: String? { criticality.correctiveAction }
    var areaTag: String? { criticality.areaName }
    var sourceModule: String { "cleaning" }
}

enum UnifiedCriticalityQuery {
    static func allOpen(
        checklistAlerts: [ChecklistAlert],
        cleaningCriticalities: [CleaningCriticality],
        restaurantId: UUID
    ) -> [any HACCPCriticalityRecord] {
        let checklist = checklistAlerts
            .filter { $0.restaurantId == restaurantId && $0.isActive }
            .map { ChecklistAlertCriticalityAdapter(alert: $0) as any HACCPCriticalityRecord }
        let cleaning = cleaningCriticalities
            .filter { $0.restaurantId == restaurantId && !$0.isResolved }
            .map { CleaningCriticalityAdapter(criticality: $0) as any HACCPCriticalityRecord }
        return (checklist + cleaning).sorted { $0.createdAt > $1.createdAt }
    }
}
