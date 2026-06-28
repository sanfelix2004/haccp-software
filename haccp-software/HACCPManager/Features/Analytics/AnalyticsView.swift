import SwiftUI
import SwiftData

struct AnalyticsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @StateObject private var vm = AnalyticsViewModel()
    @StateObject private var dataStore = AnalyticsDataStore()

    private var contentPadding: CGFloat {
        horizontalSizeClass == .regular
            ? theme.spacing.screenPadding + 16
            : theme.spacing.screenPadding
    }

    private var sectionMaxWidth: CGFloat? {
        horizontalSizeClass == .regular ? 920 : nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                periodPicker

                if let restaurantId = appState.activeRestaurantId {
                    ZStack(alignment: .top) {
                        HACCPAnalyticsSectionsView(
                            restaurantId: restaurantId,
                            vm: vm,
                            checklistRuns: dataStore.checklistRuns,
                            checklistResults: dataStore.checklistResults,
                            checklistAlerts: dataStore.checklistAlerts,
                            temperatureRecords: dataStore.temperatureRecords,
                            temperatureDevices: dataStore.temperatureDevices,
                            cleaningRecords: dataStore.cleaningRecords,
                            cleaningCriticalities: dataStore.cleaningCriticalities,
                            blastRecords: dataStore.blastRecords,
                            defrostRecords: dataStore.defrostRecords,
                            oilRecords: dataStore.oilRecords,
                            goodsRecords: dataStore.goodsRecords,
                            traceabilityRecords: dataStore.traceabilityRecords,
                            labelRecords: dataStore.labelRecords
                        )
                        .id(dataStore.loadGeneration)
                        .opacity(dataStore.isLoading ? 0.55 : 1)
                        .allowsHitTesting(!dataStore.isLoading)

                        if dataStore.isLoading && dataStore.isEmpty {
                            loadingState
                        }
                    }
                } else {
                    AnalyticsEmptyStateView(
                        title: "Nessun ristorante attivo",
                        message: "Seleziona un ristorante per visualizzare i grafici."
                    )
                }
            }
            .frame(maxWidth: sectionMaxWidth ?? .infinity)
            .frame(maxWidth: .infinity)
            .padding(contentPadding)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle("Grafici")
        .task(id: appState.activeRestaurantId) {
            dataStore.reload(context: modelContext, restaurantId: appState.activeRestaurantId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .kitchenProcessRecordsDidChange)) { _ in
            dataStore.reload(context: modelContext, restaurantId: appState.activeRestaurantId)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Caricamento grafici…")
                .font(theme.typography.subheadline)
                .foregroundStyle(theme.colorTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Grafici HACCP")
                    .font(horizontalSizeClass == .regular ? .largeTitle.bold() : theme.typography.title2.weight(.bold))
                    .foregroundStyle(theme.colorTextPrimary)
                Text("Andamento per ogni area operativa: temperature, pulizie, abbattimento, olio, ricezioni, scadenze e altro.")
                    .font(theme.typography.subheadline)
                    .foregroundStyle(theme.colorTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            ModuleHelpButton(help: ModuleHelpLibrary.sidebar(.analytics), size: 40)
        }
    }

    private var periodPicker: some View {
        HStack {
            Label("Periodo", systemImage: "calendar")
                .font(theme.typography.subheadline.weight(.semibold))
                .foregroundStyle(theme.colorTextSecondary)
            Spacer()
            AnalyticsPeriodPicker(selection: $vm.selectedPeriod)
        }
        .padding(12)
        .background(theme.colorSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
