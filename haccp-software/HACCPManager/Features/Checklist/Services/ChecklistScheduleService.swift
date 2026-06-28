import Foundation

struct ChecklistScheduleService {
    private let engine = PeriodicTaskEngine()

    func dueDateForCurrentCycle(
        frequency: ChecklistFrequency,
        scheduledHour: Int?,
        scheduledMinute: Int?,
        scheduleWeekday: Int?,
        scheduleDayOfMonth: Int?,
        scheduleMonth: Int?,
        anchorDate: Date,
        now: Date = Date()
    ) -> Date? {
        engine.dueDateForCurrentCycle(
            frequency: frequency,
            scheduledHour: scheduledHour,
            scheduledMinute: scheduledMinute,
            scheduleWeekday: scheduleWeekday,
            scheduleDayOfMonth: scheduleDayOfMonth,
            scheduleMonth: scheduleMonth,
            anchorDate: anchorDate,
            now: now
        )
    }

    func isSameCycle(_ first: Date, _ second: Date, frequency: ChecklistFrequency) -> Bool {
        engine.isSameCycle(first, second, frequency: frequency)
    }

    func shouldMaterializeRun(frequency: ChecklistFrequency, dueDate: Date, now: Date = Date()) -> Bool {
        engine.shouldMaterialize(frequency: frequency, dueDate: dueDate, now: now)
    }

    func isOverdueForDashboard(run: ChecklistRun, frequency: ChecklistFrequency, now: Date = Date()) -> Bool {
        let adapter = ChecklistRunPeriodicAdapter(run: run, frequency: frequency)
        return engine.isOverdueForDashboard(adapter, now: now)
    }

    func isVisibleOnDashboard(
        run: ChecklistRun,
        frequency: ChecklistFrequency,
        now: Date = Date()
    ) -> Bool {
        let adapter = ChecklistRunPeriodicAdapter(run: run, frequency: frequency)
        return engine.isVisibleOnDashboard(adapter, now: now)
    }

    func nextDueDate(
        frequency: ChecklistFrequency,
        scheduledHour: Int?,
        scheduledMinute: Int?,
        now: Date = Date()
    ) -> Date? {
        engine.nextDueDate(
            frequency: frequency,
            scheduledHour: scheduledHour,
            scheduledMinute: scheduledMinute,
            now: now
        )
    }
}
