import Foundation

struct ChecklistReportRow: Identifiable {
    let id: UUID
    let checklistTitle: String
    let itemTitle: String
    let result: ChecklistItemResultValue
    let correctiveAction: String
    let userName: String
    let timestamp: Date
}

struct ChecklistReportService {
    func rowsForPeriod(
        runs: [ChecklistRun],
        itemResults: [ChecklistItemResult],
        from startDate: Date,
        to endDate: Date
    ) -> [ChecklistReportRow] {
        let runById = Dictionary(uniqueKeysWithValues: runs.map { ($0.id, $0) })
        return itemResults.compactMap { item in
            guard let run = runById[item.checklistRunId] else { return nil }
            guard run.startedAt >= startDate && run.startedAt <= endDate else { return nil }

            return ChecklistReportRow(
                id: item.id,
                checklistTitle: run.templateTitleSnapshot,
                itemTitle: item.titleSnapshot,
                result: item.result,
                correctiveAction: item.note ?? "-",
                userName: run.completedByNameSnapshot ?? "-",
                timestamp: item.completedAt ?? run.startedAt
            )
        }
        .sorted(by: { $0.timestamp > $1.timestamp })
    }
}
