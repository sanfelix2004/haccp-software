import Foundation
import Combine

@MainActor
final class ChecklistHistoryViewModel: ObservableObject {
    @Published var fromDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date.distantPast
    @Published var toDate: Date = Date()
    @Published var categoryFilter: ChecklistCategory?
    @Published var statusFilter: ChecklistRunStatus?

    func filteredRuns(
        runs: [ChecklistRun],
        templates: [ChecklistTemplate]
    ) -> [ChecklistRun] {
        let templateById = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: fromDate)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: calendar.startOfDay(for: toDate)) ?? toDate

        return runs
            .filter { $0.status == .completed || $0.status == .failed || $0.status == .archived }
            .filter { $0.startedAt >= start && $0.startedAt <= end }
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
