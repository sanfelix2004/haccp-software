import Foundation

/// Stato di ciclo unificato per checklist, pulizie e futuri moduli periodici.
enum PeriodicTaskLifecycleStatus: Equatable {
    case pending
    case inProgress
    case completed
    case failed
    case notApplicable
    case overdue
    case missed
    case archived

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .notApplicable, .missed, .archived:
            return true
        case .pending, .inProgress, .overdue:
            return false
        }
    }

    var isOpen: Bool {
        switch self {
        case .pending, .inProgress, .overdue:
            return true
        default:
            return false
        }
    }
}

/// Frequenza normalizzata tra moduli.
enum PeriodicFrequencyKind: Equatable {
    case daily
    case weekly
    case monthly
    case annual
    case custom(days: Int)
    case onDemand

    var supportsScheduledCycles: Bool {
        switch self {
        case .daily, .weekly, .monthly, .annual, .custom:
            return true
        case .onDemand:
            return false
        }
    }
}

/// Come un task compare nella dashboard operativa.
enum PeriodicVisibilityRule: Equatable {
    /// Checklist periodiche: visibili solo nel giorno di scadenza (JIT).
    case justInTimeDueDay
    /// Pulizie e giornaliere: visibili per tutto il ciclo corrente.
    case currentCycle
}

/// Contratto di lettura condiviso — nessuna mutazione su `@Model`.
protocol HACCPPeriodicTask {
    var id: UUID { get }
    var restaurantId: UUID { get }
    var taskName: String { get }
    var areaTag: String? { get }
    var categoryTag: String { get }
    var dueDate: Date { get }
    var cycleAnchor: Date { get }
    var lifecycleStatus: PeriodicTaskLifecycleStatus { get }
    var frequencyKind: PeriodicFrequencyKind { get }
    var visibilityRule: PeriodicVisibilityRule { get }
}

extension HACCPPeriodicTask {
    var isTerminal: Bool { lifecycleStatus.isTerminal }
    var isOpen: Bool { lifecycleStatus.isOpen }
}

// MARK: - Frequency mappings

extension ChecklistFrequency {
    var periodicKind: PeriodicFrequencyKind {
        switch self {
        case .daily: return .daily
        case .weekly: return .weekly
        case .monthly: return .monthly
        case .annual: return .annual
        case .onDemand: return .onDemand
        case .custom: return .custom(days: 1)
        }
    }
}

extension CleaningTaskFrequency {
    var periodicKind: PeriodicFrequencyKind {
        switch self {
        case .giornaliero: return .daily
        case .settimanale: return .weekly
        case .mensile: return .monthly
        case .personalizzato: return .custom(days: 1)
        }
    }

    var checklistFrequency: ChecklistFrequency {
        switch self {
        case .giornaliero: return .daily
        case .settimanale: return .weekly
        case .mensile: return .monthly
        case .personalizzato: return .custom
        }
    }
}
