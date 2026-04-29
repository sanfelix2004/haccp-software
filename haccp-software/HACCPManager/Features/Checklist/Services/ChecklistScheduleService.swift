import Foundation

struct ChecklistScheduleService {
    func dueDateForCurrentCycle(
        frequency: ChecklistFrequency,
        scheduledHour: Int?,
        scheduledMinute: Int?,
        anchorDate: Date,
        now: Date = Date()
    ) -> Date? {
        var calendar = Calendar.current
        calendar.timeZone = .current

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = scheduledHour ?? 9
        components.minute = scheduledMinute ?? 0
        components.second = 0
        let todayAtSchedule = calendar.date(from: components) ?? now

        switch frequency {
        case .daily:
            return todayAtSchedule
        case .weekly:
            let anchorWeekday = calendar.component(.weekday, from: anchorDate)
            var weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            weekComponents.weekday = anchorWeekday
            weekComponents.hour = scheduledHour ?? 9
            weekComponents.minute = scheduledMinute ?? 0
            weekComponents.second = 0
            return calendar.date(from: weekComponents)
        case .monthly:
            let anchorDay = calendar.component(.day, from: anchorDate)
            let range = calendar.range(of: .day, in: .month, for: now) ?? (1..<29)
            let day = min(anchorDay, range.count)
            components.day = day
            return calendar.date(from: components)
        case .onDemand, .custom:
            return nil
        }
    }

    func isSameCycle(_ first: Date, _ second: Date, frequency: ChecklistFrequency) -> Bool {
        let calendar = Calendar.current
        switch frequency {
        case .daily:
            return calendar.isDate(first, inSameDayAs: second)
        case .weekly:
            return calendar.isDate(first, equalTo: second, toGranularity: .weekOfYear)
        case .monthly:
            return calendar.isDate(first, equalTo: second, toGranularity: .month)
        case .onDemand, .custom:
            return false
        }
    }

    func nextDueDate(
        frequency: ChecklistFrequency,
        scheduledHour: Int?,
        scheduledMinute: Int?,
        now: Date = Date()
    ) -> Date? {
        var calendar = Calendar.current
        calendar.timeZone = .current

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = scheduledHour ?? 9
        components.minute = scheduledMinute ?? 0
        components.second = 0
        let baseToday = calendar.date(from: components) ?? now

        switch frequency {
        case .daily:
            return baseToday > now ? baseToday : calendar.date(byAdding: .day, value: 1, to: baseToday)
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: baseToday)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: baseToday)
        case .onDemand, .custom:
            return nil
        }
    }
}
