import SwiftUI
import SwiftData

struct AnalyticsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme

    @Query private var checklistRuns: [ChecklistRun]
    @Query private var checklistResults: [ChecklistItemResult]
    @Query private var checklistAlerts: [ChecklistAlert]
    @Query private var temperatureRecords: [TemperatureRecord]
    @Query private var temperatureDevices: [TemperatureDevice]
    @Query private var cleaningRecords: [CleaningRecord]
    @Query private var cleaningCriticalities: [CleaningCriticality]
    @Query private var blastRecords: [BlastChillingRecord]
    @Query private var defrostRecords: [DefrostRecord]
    @Query private var oilRecords: [OilControlRecord]
    @Query private var goodsRecords: [GoodsReceivingRecord]
    @Query private var traceabilityRecords: [TraceabilityRecord]
    @Query private var labelRecords: [ProductionLabelRecord]

    @StateObject private var vm = AnalyticsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                periodPicker

                if let restaurantId = appState.activeRestaurantId {
                    HACCPAnalyticsSectionsView(
                        restaurantId: restaurantId,
                        vm: vm,
                        checklistRuns: checklistRuns,
                        checklistResults: checklistResults,
                        checklistAlerts: checklistAlerts,
                        temperatureRecords: temperatureRecords,
                        temperatureDevices: temperatureDevices,
                        cleaningRecords: cleaningRecords,
                        cleaningCriticalities: cleaningCriticalities,
                        blastRecords: blastRecords,
                        defrostRecords: defrostRecords,
                        oilRecords: oilRecords,
                        goodsRecords: goodsRecords,
                        traceabilityRecords: traceabilityRecords,
                        labelRecords: labelRecords
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
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle("Grafici")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Grafici HACCP")
                    .font(.largeTitle.bold())
                    .foregroundStyle(theme.colorTextPrimary)
                Text("Andamento per ogni area operativa: temperature, pulizie, abbattimento, olio, ricezioni, scadenze e altro.")
                    .font(.subheadline)
                    .foregroundStyle(theme.colorTextSecondary)
            }
            Spacer(minLength: 0)
            ModuleHelpButton(help: ModuleHelpLibrary.sidebar(.analytics), size: 40)
        }
    }

    private var periodPicker: some View {
        HStack {
            Label("Periodo", systemImage: "calendar")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.colorTextSecondary)
            Spacer()
            AnalyticsPeriodPicker(selection: $vm.selectedPeriod)
        }
        .padding(12)
        .background(theme.colorSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
