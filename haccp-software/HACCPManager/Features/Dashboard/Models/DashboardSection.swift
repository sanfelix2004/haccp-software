import Foundation

enum DashboardSection: String, CaseIterable, Identifiable {
    case modules = "Moduli HACCP"
    case checklist = "Checklist"
    case charts = "Grafici e andamento"
    case recentActivities = "Attività recenti"
    case alerts = "Avvisi"

    var id: String { rawValue }
}

struct DashboardRecentActivity: Identifiable {
    let id = UUID()
    let userName: String
    let action: String
    let date: Date
    let module: String
    let severity: String
}

struct DashboardAlertItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let date: Date
    let type: String
}

struct DashboardChecklistItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
}
