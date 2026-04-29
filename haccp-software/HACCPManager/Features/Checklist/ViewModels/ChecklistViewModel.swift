import Foundation
import Combine

@MainActor
final class ChecklistViewModel: ObservableObject {
    @Published var selectedTab: ChecklistTab = .dashboard
    @Published var showCreateTemplate = false
    @Published var errorMessage: String?

    let service = ChecklistService()

    func dashboardCounts(runs: [ChecklistRun], alerts: [ChecklistAlert]) -> (todo: Int, inProgress: Int, completed: Int, critical: Int) {
        let todo = runs.filter { $0.status == .notStarted || $0.status == .overdue }.count
        let inProgress = runs.filter { $0.status == .inProgress }.count
        let completed = runs.filter { $0.status == .completed }.count
        let critical = alerts.filter { $0.isActive && ($0.severity == .high || $0.severity == .critical) }.count
        return (todo, inProgress, completed, critical)
    }
}

enum ChecklistTab: String, CaseIterable, Identifiable {
    case dashboard = "Checklist"
    case templates = "Modelli"
    case alerts = "Criticita"

    var id: String { rawValue }
}
