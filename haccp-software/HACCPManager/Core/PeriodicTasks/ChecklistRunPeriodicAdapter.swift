import Foundation

struct ChecklistRunPeriodicAdapter: HACCPPeriodicTask {
    let run: ChecklistRun
    let frequency: ChecklistFrequency
    var category: ChecklistCategory = .custom
    var areaTag: String? = nil

    var id: UUID { run.id }
    var restaurantId: UUID { run.restaurantId }
    var taskName: String { run.templateTitleSnapshot }
    var categoryTag: String { category.rawValue }
    var dueDate: Date { run.dueAt ?? run.startedAt }
    var cycleAnchor: Date { run.dueAt ?? run.startedAt }
    var frequencyKind: PeriodicFrequencyKind { frequency.periodicKind }

    var visibilityRule: PeriodicVisibilityRule {
        switch frequency {
        case .daily:
            return .currentCycle
        case .weekly, .monthly, .annual:
            return .justInTimeDueDay
        case .onDemand, .custom:
            return .justInTimeDueDay
        }
    }

    var lifecycleStatus: PeriodicTaskLifecycleStatus {
        switch run.status {
        case .notStarted: return .pending
        case .inProgress: return .inProgress
        case .completed: return .completed
        case .overdue: return .overdue
        case .failed: return .failed
        case .missed: return .missed
        case .archived: return .archived
        }
    }
}
