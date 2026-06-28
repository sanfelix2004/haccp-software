import Foundation

/// Motore condiviso per cicli, visibilità dashboard, ritardi e chiusura «non fatta».
struct PeriodicTaskEngine {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func isSameCycle(_ first: Date, _ second: Date, frequency: PeriodicFrequencyKind) -> Bool {
        switch frequency {
        case .daily:
            return calendar.isDate(first, inSameDayAs: second)
        case .weekly:
            return calendar.isDate(first, equalTo: second, toGranularity: .weekOfYear)
        case .monthly:
            return calendar.isDate(first, equalTo: second, toGranularity: .month)
        case .annual:
            return calendar.isDate(first, equalTo: second, toGranularity: .year)
        case .custom(let days):
            guard days > 0 else { return false }
            let startFirst = calendar.startOfDay(for: first)
            let startSecond = calendar.startOfDay(for: second)
            let delta = abs(calendar.dateComponents([.day], from: startFirst, to: startSecond).day ?? 0)
            return delta / days == 0
        case .onDemand:
            return false
        }
    }

    func isSameCycle(_ first: Date, _ second: Date, frequency: ChecklistFrequency) -> Bool {
        isSameCycle(first, second, frequency: frequency.periodicKind)
    }

    func shouldMaterialize(frequency: PeriodicFrequencyKind, dueDate: Date, now: Date = Date()) -> Bool {
        switch frequency {
        case .daily, .custom:
            return true
        case .weekly, .monthly, .annual:
            let startOfDue = calendar.startOfDay(for: dueDate)
            let startOfNow = calendar.startOfDay(for: now)
            return startOfNow >= startOfDue
        case .onDemand:
            return false
        }
    }

    func shouldMaterialize(frequency: ChecklistFrequency, dueDate: Date, now: Date = Date()) -> Bool {
        shouldMaterialize(frequency: frequency.periodicKind, dueDate: dueDate, now: now)
    }

    /// Ritardo visibile solo nel giorno/ciclo corrente di scadenza.
    func isOverdueForDashboard(_ task: any HACCPPeriodicTask, now: Date = Date()) -> Bool {
        if task.lifecycleStatus == .inProgress { return false }
        if task.lifecycleStatus == .overdue { return true }

        guard task.lifecycleStatus == .pending else { return false }

        switch task.visibilityRule {
        case .justInTimeDueDay:
            guard calendar.isDateInToday(task.dueDate) else { return false }
            return task.dueDate < now
        case .currentCycle:
            guard isInCurrentCycle(task: task, now: now) else { return false }
            return task.dueDate < now
        }
    }

    func isVisibleOnDashboard(_ task: any HACCPPeriodicTask, now: Date = Date()) -> Bool {
        if task.lifecycleStatus == .inProgress { return true }
        if isOverdueForDashboard(task, now: now) { return true }
        guard task.lifecycleStatus == .pending else { return false }

        switch task.visibilityRule {
        case .justInTimeDueDay:
            return calendar.isDateInToday(task.dueDate)
        case .currentCycle:
            return isInCurrentCycle(task: task, now: now)
        }
    }

    /// Ciclo passato ancora aperto → va chiuso come «non fatta».
    func shouldCloseAsMissed(
        _ task: any HACCPPeriodicTask,
        currentCycleDue: Date,
        now: Date = Date()
    ) -> Bool {
        guard task.isOpen else { return false }
        return !isSameCycle(task.cycleAnchor, currentCycleDue, frequency: task.frequencyKind)
    }

    func isInCurrentCycle(task: any HACCPPeriodicTask, now: Date) -> Bool {
        let referenceDue = dueDateForCurrentCycle(
            frequency: task.frequencyKind,
            anchorDate: task.cycleAnchor,
            now: now
        ) ?? task.cycleAnchor
        return isSameCycle(task.cycleAnchor, referenceDue, frequency: task.frequencyKind)
    }

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
        var cal = calendar
        cal.timeZone = .current

        let hour = scheduledHour ?? 9
        let minute = scheduledMinute ?? 0

        switch frequency {
        case .daily:
            var components = cal.dateComponents([.year, .month, .day], from: now)
            components.hour = hour
            components.minute = minute
            components.second = 0
            return cal.date(from: components)

        case .weekly:
            let weekday = scheduleWeekday ?? cal.component(.weekday, from: anchorDate)
            var weekComponents = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            weekComponents.weekday = weekday
            weekComponents.hour = hour
            weekComponents.minute = minute
            weekComponents.second = 0
            return cal.date(from: weekComponents)

        case .monthly:
            let anchorDay = scheduleDayOfMonth ?? cal.component(.day, from: anchorDate)
            var components = cal.dateComponents([.year, .month], from: now)
            let range = cal.range(of: .day, in: .month, for: now) ?? (1..<29)
            components.day = min(max(1, anchorDay), range.count)
            components.hour = hour
            components.minute = minute
            components.second = 0
            return cal.date(from: components)

        case .annual:
            let month = scheduleMonth ?? cal.component(.month, from: anchorDate)
            let anchorDay = scheduleDayOfMonth ?? cal.component(.day, from: anchorDate)
            var components = cal.dateComponents([.year], from: now)
            components.month = month
            let probe = cal.date(from: components) ?? now
            let range = cal.range(of: .day, in: .month, for: probe) ?? (1..<29)
            components.day = min(max(1, anchorDay), range.count)
            components.hour = hour
            components.minute = minute
            components.second = 0
            return cal.date(from: components)

        case .onDemand, .custom:
            return nil
        }
    }

    func dueDateForCurrentCycle(
        frequency: PeriodicFrequencyKind,
        anchorDate: Date,
        now: Date = Date()
    ) -> Date? {
        dueDateForCurrentCycle(
            frequency: checklistFrequency(from: frequency),
            scheduledHour: 9,
            scheduledMinute: 0,
            scheduleWeekday: calendar.component(.weekday, from: anchorDate),
            scheduleDayOfMonth: calendar.component(.day, from: anchorDate),
            scheduleMonth: calendar.component(.month, from: anchorDate),
            anchorDate: anchorDate,
            now: now
        )
    }

    func periodInterval(for frequency: CleaningTaskFrequency, customIntervalDays: Int?, reference: Date) -> DateInterval {
        switch frequency {
        case .giornaliero:
            let start = calendar.startOfDay(for: reference)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
            return DateInterval(start: start, end: end)
        case .settimanale:
            return calendar.dateInterval(of: .weekOfYear, for: reference)
                ?? DateInterval(start: reference, end: reference.addingTimeInterval(86400))
        case .mensile:
            return calendar.dateInterval(of: .month, for: reference)
                ?? DateInterval(start: reference, end: reference.addingTimeInterval(86400))
        case .personalizzato:
            let interval = max(customIntervalDays ?? 1, 1)
            let start = calendar.startOfDay(for: reference)
            let end = calendar.date(byAdding: .day, value: interval, to: start)
                ?? start.addingTimeInterval(Double(interval) * 86400)
            return DateInterval(start: start, end: end)
        }
    }

    func nextDueDate(
        frequency: ChecklistFrequency,
        scheduledHour: Int?,
        scheduledMinute: Int?,
        now: Date = Date()
    ) -> Date? {
        var cal = calendar
        cal.timeZone = .current

        var components = cal.dateComponents([.year, .month, .day], from: now)
        components.hour = scheduledHour ?? 9
        components.minute = scheduledMinute ?? 0
        components.second = 0
        let baseToday = cal.date(from: components) ?? now

        switch frequency {
        case .daily:
            return baseToday > now ? baseToday : cal.date(byAdding: .day, value: 1, to: baseToday)
        case .weekly:
            return cal.date(byAdding: .day, value: 7, to: baseToday)
        case .monthly:
            return cal.date(byAdding: .month, value: 1, to: baseToday)
        case .annual:
            return cal.date(byAdding: .year, value: 1, to: baseToday)
        case .onDemand, .custom:
            return nil
        }
    }

    private func checklistFrequency(from kind: PeriodicFrequencyKind) -> ChecklistFrequency {
        switch kind {
        case .daily: return .daily
        case .weekly: return .weekly
        case .monthly: return .monthly
        case .annual: return .annual
        case .custom, .onDemand: return .onDemand
        }
    }
}
