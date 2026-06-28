//
//  ChecklistDesign.swift
//  Icone, badge e copy condivisi per il modulo checklist.
//

import SwiftUI

extension ChecklistCategory {
    var systemImage: String {
        switch self {
        case .opening: return "sun.horizon.fill"
        case .closing: return "moon.stars.fill"
        case .cleaning: return "sparkles"
        case .personalHygiene: return "hands.sparkles.fill"
        case .foodStorage: return "refrigerator.fill"
        case .foodPreparation: return "frying.pan.fill"
        case .crossContamination: return "arrow.triangle.branch"
        case .allergens: return "exclamationmark.triangle.fill"
        case .receivingGoods: return "shippingbox.fill"
        case .waste: return "trash.fill"
        case .equipment: return "wrench.and.screwdriver.fill"
        case .custom: return "checklist"
        case .quickTask: return "bolt.circle.fill"
        }
    }
}

extension ChecklistFrequency {
    var systemImage: String {
        switch self {
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar"
        case .monthly: return "calendar.badge.clock"
        case .annual: return "calendar.badge.exclamationmark"
        case .onDemand: return "hand.tap.fill"
        case .custom: return "slider.horizontal.3"
        }
    }
}

extension ChecklistRunStatus {
    var badgeStyle: HACCPBadgeStyle {
        switch self {
        case .completed: return .conforme
        case .inProgress: return .info
        case .overdue, .failed: return .nonConforme
        case .notStarted: return .neutral
        case .missed, .archived: return .neutral
        }
    }

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .missed, .archived: return true
        case .notStarted, .inProgress, .overdue: return false
        }
    }
}

extension ChecklistItemResultValue {
    var badgeStyle: HACCPBadgeStyle {
        switch self {
        case .pass: return .conforme
        case .fail: return .nonConforme
        case .notApplicable: return .neutral
        case .pending: return .warning
        }
    }

    var systemImage: String {
        switch self {
        case .pass: return "checkmark.circle.fill"
        case .fail: return "xmark.circle.fill"
        case .notApplicable: return "minus.circle.fill"
        case .pending: return "circle"
        }
    }
}

struct ChecklistProgressSummary: Equatable {
    let completed: Int
    let total: Int
    let progressPercentage: Int
    let hasFailures: Bool
    let failedCount: Int

    static func from(run: ChecklistRun, results: [ChecklistItemResult]) -> ChecklistProgressSummary {
        let scoped = results.filter { $0.checklistRunId == run.id }
        let total = scoped.count
        guard total > 0 else {
            return ChecklistProgressSummary(
                completed: 0,
                total: 0,
                progressPercentage: 0,
                hasFailures: false,
                failedCount: 0
            )
        }
        let completed = scoped.filter {
            $0.result == .pass || $0.result == .fail || $0.result == .notApplicable
        }.count
        let failedCount = scoped.filter { $0.result == .fail }.count
        let hasFailures = failedCount > 0
        let percentage = Int((Double(completed) / Double(total) * 100).rounded())
        return ChecklistProgressSummary(
            completed: completed,
            total: total,
            progressPercentage: percentage,
            hasFailures: hasFailures,
            failedCount: failedCount
        )
    }
}
