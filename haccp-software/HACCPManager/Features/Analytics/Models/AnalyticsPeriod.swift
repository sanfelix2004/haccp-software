import Foundation

enum AnalyticsPeriod: String, CaseIterable, Identifiable {
    case today
    case sevenDays
    case thirtyDays

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: return "Oggi"
        case .sevenDays: return "7 giorni"
        case .thirtyDays: return "30 giorni"
        }
    }

    func startDate(now: Date = Date()) -> Date {
        let calendar = Calendar.current
        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .sevenDays:
            return calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        case .thirtyDays:
            return calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now)) ?? now
        }
    }
}
