import Foundation

enum DashboardChartType: String, CaseIterable, Identifiable {
    case temperatureTrend = "Andamento temperature"
    case checklistCompletion = "Completamento checklist"
    case dailyActivities = "Attivita per giorno"
    case criticalEvents = "Criticita rilevate"
    case cleaningCompletion = "Pulizie completate"
    case expiringProducts = "Prodotti in scadenza"

    var id: String { rawValue }
}
