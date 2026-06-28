import Foundation

/// Query condivise per dashboard e conteggi operativi.
enum PeriodicTaskDashboardQuery {
    private static let engine = PeriodicTaskEngine()

    static func isVisibleOnDashboard(_ task: any HACCPPeriodicTask, now: Date = Date()) -> Bool {
        engine.isVisibleOnDashboard(task, now: now)
    }

    static func isOverdueForDashboard(_ task: any HACCPPeriodicTask, now: Date = Date()) -> Bool {
        engine.isOverdueForDashboard(task, now: now)
    }

    static func checklistRun(
        _ run: ChecklistRun,
        frequency: ChecklistFrequency,
        category: ChecklistCategory = .custom,
        areaTag: String? = nil
    ) -> ChecklistRunPeriodicAdapter {
        ChecklistRunPeriodicAdapter(
            run: run,
            frequency: frequency,
            category: category,
            areaTag: areaTag
        )
    }

    static func cleaningRecord(
        _ record: CleaningRecord,
        currentPeriodStart: Date,
        hasOpenCriticality: Bool,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> CleaningRecordPeriodicAdapter {
        CleaningRecordPeriodicAdapter(
            record: record,
            currentPeriodStart: currentPeriodStart,
            hasOpenCriticality: hasOpenCriticality,
            now: now,
            engine: PeriodicTaskEngine(calendar: calendar)
        )
    }
}
