import Foundation
import Combine

@MainActor
final class ChecklistViewModel: ObservableObject {
    @Published var selectedTab: ChecklistTab = .dashboard
    @Published var showCreateTemplate = false
    @Published var showQuickTaskSheet = false
    @Published var errorMessage: String?

    let service = ChecklistService()

    func dashboardCounts(
        runs: [ChecklistRun],
        templates: [ChecklistTemplate]
    ) -> (todo: Int, inProgress: Int, completed: Int) {
        let engine = PeriodicTaskEngine()
        let templateById = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })

        let active = runs.filter { !$0.status.isTerminal }

        let todo = active.filter { run in
            if run.status == .inProgress { return false }
            guard let template = templateById[run.templateId] else { return false }
            let adapter = ChecklistRunPeriodicAdapter(
                run: run,
                frequency: template.frequency,
                category: template.category,
                areaTag: template.areaTag
            )
            return engine.isVisibleOnDashboard(adapter)
        }.count

        let inProgress = active.filter { $0.status == .inProgress }.count
        let completed = runs.filter { $0.status == .completed }.count
        return (todo, inProgress, completed)
    }
}

enum ChecklistTab: String, CaseIterable, Identifiable {
    case templates = "Modelli"
    case dashboard = "Oggi"
    case history = "Storico"
    case alerts = "Criticità"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .alerts: return "Checklist e pulizie unite"
        default: return rawValue
        }
    }
}
