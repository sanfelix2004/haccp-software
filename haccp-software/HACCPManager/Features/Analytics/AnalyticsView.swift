import SwiftUI
import SwiftData

struct AnalyticsView: View {
    @EnvironmentObject var appState: AppState
    @Query private var checklistRuns: [ChecklistRun]
    @Query private var checklistResults: [ChecklistItemResult]
    @Query private var checklistAlerts: [ChecklistAlert]
    @Query private var temperatureRecords: [TemperatureRecord]
    @Query private var temperatureDevices: [TemperatureDevice]

    @StateObject private var vm = AnalyticsViewModel()

    private var restaurantId: UUID? {
        appState.activeRestaurantId
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Grafici")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    Text("Analizza controlli, checklist e temperature del ristorante")
                        .foregroundColor(.gray)
                }

                if let restaurantId {
                    let checklistPoints = vm.checklistPoints(
                        restaurantId: restaurantId,
                        runs: checklistRuns,
                        itemResults: checklistResults,
                        alerts: checklistAlerts
                    )
                    let checklistKpis = vm.checklistKPIs(
                        points: checklistPoints,
                        alerts: checklistAlerts,
                        restaurantId: restaurantId
                    )
                    let temperaturePoints = vm.temperaturePoints(
                        restaurantId: restaurantId,
                        records: temperatureRecords
                    )
                    let temperatureKpis = vm.temperatureKPIs(points: temperaturePoints)
                    let scopedDevices = temperatureDevices
                        .filter { $0.restaurantId == restaurantId && $0.isActive }
                        .sorted(by: { $0.name < $1.name })

                    ChecklistAnalyticsCard(points: checklistPoints, kpis: checklistKpis)
                    TemperatureAnalyticsCard(
                        points: temperaturePoints,
                        kpis: temperatureKpis,
                        devices: scopedDevices,
                        selectedDeviceId: $vm.selectedDeviceId,
                        selectedPeriod: $vm.selectedPeriod
                    )
                } else {
                    AnalyticsEmptyStateView(
                        title: "Nessun ristorante attivo",
                        message: "Seleziona un ristorante per visualizzare i grafici."
                    )
                }
            }
            .padding(24)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Grafici")
    }
}
