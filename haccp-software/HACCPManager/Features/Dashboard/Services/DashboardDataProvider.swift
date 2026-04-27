import Foundation

protocol DashboardDataProviding {
    func fetchChecklistItems() -> [DashboardChecklistItem]
    func fetchRecentActivities() -> [DashboardRecentActivity]
    func fetchAlerts() -> [DashboardAlertItem]
}

struct DashboardDataProvider: DashboardDataProviding {
    func fetchChecklistItems() -> [DashboardChecklistItem] { [] }
    func fetchRecentActivities() -> [DashboardRecentActivity] { [] }
    func fetchAlerts() -> [DashboardAlertItem] { [] }
}
