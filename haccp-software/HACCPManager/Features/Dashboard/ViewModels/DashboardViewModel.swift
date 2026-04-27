import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var currentDate = Date()
    @Published private(set) var checklistItems: [DashboardChecklistItem] = []
    @Published private(set) var recentActivities: [DashboardRecentActivity] = []
    @Published private(set) var alerts: [DashboardAlertItem] = []

    let restaurantName = "Romanazzi / Soso Restaurant"
    let modules: [DashboardModule] = [
        .init(name: "Temperature", description: "Monitoraggio e registrazioni termiche", icon: "thermometer.medium", state: .configure, isEnabled: false),
        .init(name: "Checklist", description: "Procedure operative giornaliere", icon: "checklist", state: .open, isEnabled: true),
        .init(name: "Pulizie", description: "Piani e conferme di sanificazione", icon: "sparkles", state: .configure, isEnabled: false),
        .init(name: "Prodotti", description: "Lotti, scadenze e tracciabilita", icon: "archivebox.fill", state: .configure, isEnabled: false),
        .init(name: "Etichette", description: "Gestione etichette di preparazione", icon: "tag.fill", state: .configure, isEnabled: false),
        .init(name: "Scongelamento", description: "Controllo procedure di scongelamento", icon: "snowflake", state: .configure, isEnabled: false),
        .init(name: "Abbattimento", description: "Flussi e registrazioni abbattitore", icon: "wind.snow", state: .configure, isEnabled: false),
        .init(name: "Report", description: "Esportazioni e storico conformita", icon: "doc.text.fill", state: .open, isEnabled: true)
    ]
    let chartTypes: [DashboardChartType] = DashboardChartType.allCases

    private let provider: DashboardDataProviding
    private var timer: Timer?

    init(provider: DashboardDataProviding) {
        self.provider = provider
        reload()
        startClock()
    }

    deinit {
        timer?.invalidate()
    }

    func reload() {
        checklistItems = provider.fetchChecklistItems()
        recentActivities = provider.fetchRecentActivities()
        alerts = provider.fetchAlerts()
    }

    var formattedDateTime: String {
        currentDate.formatted(date: .abbreviated, time: .shortened)
    }

    private func startClock() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.currentDate = Date()
        }
    }
}
