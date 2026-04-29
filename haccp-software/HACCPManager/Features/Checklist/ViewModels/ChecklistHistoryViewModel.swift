import Foundation
import Combine

@MainActor
final class ChecklistHistoryViewModel: ObservableObject {
    @Published var fromDate: Date = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date.distantPast
    @Published var categoryFilter: ChecklistCategory?
    @Published var statusFilter: ChecklistRunStatus?

    func filteredRuns(
        runs: [ChecklistRun],
        templates: [ChecklistTemplate]
    ) -> [ChecklistRun] {
        let templateById = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
        return runs
            .filter { $0.startedAt >= fromDate }
            .filter { run in
                guard let statusFilter else { return true }
                return run.status == statusFilter
            }
            .filter { run in
                guard let categoryFilter else { return true }
                guard let template = templateById[run.templateId] else { return false }
                return template.category == categoryFilter
            }
            .sorted(by: { $0.startedAt > $1.startedAt })
    }
}
