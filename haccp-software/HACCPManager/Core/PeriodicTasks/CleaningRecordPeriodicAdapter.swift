import Foundation

struct CleaningRecordPeriodicAdapter: HACCPPeriodicTask {
    let record: CleaningRecord
    let currentPeriodStart: Date
    let hasOpenCriticality: Bool
    let now: Date
    let engine: PeriodicTaskEngine

    var id: UUID { record.id }
    var restaurantId: UUID { record.restaurantId }
    var taskName: String { record.taskName }
    var areaTag: String? { record.areaName }
    var categoryTag: String { ChecklistCategory.cleaning.rawValue }
    var dueDate: Date {
        engine.calendar.date(byAdding: .second, value: -1, to: record.periodEnd) ?? record.periodEnd
    }
    var cycleAnchor: Date { record.periodStart }
    var frequencyKind: PeriodicFrequencyKind { record.frequency.periodicKind }
    var visibilityRule: PeriodicVisibilityRule { .currentCycle }

    var lifecycleStatus: PeriodicTaskLifecycleStatus {
        if record.isArchived { return .archived }
        if record.outcome == .nonFatto { return .missed }
        if hasOpenCriticality || record.outcome == .nonPulito { return .failed }
        switch record.outcome {
        case .pulito: return .completed
        case .nonApplicabile: return .notApplicable
        case .daFare:
            if record.periodStart != currentPeriodStart { return .missed }
            if engine.isOverdueForDashboard(self, now: now) { return .overdue }
            return .pending
        case .nonPulito, .nonFatto:
            return record.outcome == .nonFatto ? .missed : .failed
        }
    }
}
