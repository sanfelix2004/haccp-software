import SwiftUI
import SwiftData

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme

    private let haccpDashboardModules: [(item: SidebarItem, description: String, icon: String)] = [
        (.traceability, "Prodotti, lotti, fornitori", "archivebox.fill"),
        (.fridges, "Temperature e allarmi", "thermometer.medium"),
        (.cleaningControl, "Piani pulizia", "sparkles"),
        (.blastChilling, "Abbattimento termico", "wind.snow"),
        (.scheduling, "Attività periodiche", "calendar.badge.clock"),
        (.expiryControl, "Scadenze prodotti", "calendar.badge.exclamationmark"),
        (.defrost, "Decongelamenti", "snowflake"),
        (.oilControl, "Olio frittura", "drop.fill"),
        (.productionLabels, "Etichette produzione", "tag.fill"),
        (.goodsReceiving, "Ingresso merci", "shippingbox.fill")
    ]

    @Environment(\.modelContext) private var modelContext
    @Query private var users: [LocalUser]
    @Query private var restaurants: [Restaurant]
    @Query private var stores: [AppDataStore]

    @StateObject private var viewModel: DashboardViewModel
    @State private var appeared = false
    @State private var metrics = DashboardMetrics.empty

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    init() {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(provider: DashboardDataProvider()))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.sectionSpacing) {
                DashboardHeaderView(
                    user: currentUser,
                    restaurant: activeRestaurant,
                    dateTimeText: viewModel.formattedDateTime,
                    systemStateMessage: "Sistema pronto · \(activeRestaurant?.name ?? "HACCP")"
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                statsRow
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                DashboardCardView(title: "Moduli HACCP", subtitle: "Accesso rapido alle registrazioni") {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(haccpDashboardModules, id: \.item) { row in
                            Button {
                                HapticManager.shared.selection()
                                appState.pendingSidebarNavigation = row.item
                            } label: {
                                ModuleTileView(
                                    title: row.item.rawValue,
                                    icon: row.icon,
                                    description: row.description,
                                    badge: badgeCount(for: row.item)
                                )
                            }
                            .buttonStyle(PremiumPressButtonStyle())
                        }
                    }
                }

                DashboardCardView(title: "Sistema e archivi", subtitle: "Documenti, storico e report") {
                    LazyVGrid(columns: columns, spacing: 16) {
                        archiveTile(
                            title: "Documenti",
                            icon: "folder.fill",
                            description: "Archivio PDF e registri",
                            badge: countForDocuments,
                            target: .documents
                        )
                        archiveTile(
                            title: "Storia",
                            icon: "clock.arrow.circlepath",
                            description: "Registrazioni centralizzate",
                            badge: nil,
                            target: .history
                        )
                        archiveTile(
                            title: "Grafici",
                            icon: "chart.xyaxis.line",
                            description: "Analytics conformità",
                            badge: nil,
                            target: .analytics
                        )
                    }
                }
            }
            .padding(theme.spacing.screenPadding + 8)
        }
        .background(Color.clear)
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(theme.spring) { appeared = true }
            viewModel.reload()
        }
        .task(id: activeRestaurantId) {
            guard let rid = activeRestaurantId else {
                metrics = .empty
                return
            }
            metrics = DashboardMetricsFetcher.fetch(context: modelContext, restaurantId: rid)
        }
    }

    private var statsRow: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            StatCard(
                title: "Conformità oggi",
                value: "\(complianceScore)%",
                subtitle: "Indice stimato",
                icon: "checkmark.shield.fill",
                accent: theme.colorSuccess
            )
            StatCard(
                title: "Alert attivi",
                value: "\(activeAlertsCount)",
                subtitle: temperatureAlertsLabel,
                icon: "bell.badge.fill",
                accent: activeAlertsCount > 0 ? theme.colorError : theme.colorTextSecondary
            )
            StatCard(
                title: "Task aperti",
                value: "\(openTasksCount)",
                subtitle: "Programmazione",
                icon: "calendar.badge.clock",
                accent: theme.colorInfo
            )
            StatCard(
                title: "Registrazioni",
                value: "\(recordsCount)",
                subtitle: "Oggi nel sistema",
                icon: "doc.text.fill",
                accent: theme.colorPrimary
            )
        }
    }

    private func archiveTile(title: String, icon: String, description: String, badge: Int?, target: SidebarItem) -> some View {
        Button {
            HapticManager.shared.selection()
            appState.pendingSidebarNavigation = target
        } label: {
            ModuleTileView(title: title, icon: icon, description: description, badge: badge)
        }
        .buttonStyle(PremiumPressButtonStyle())
    }

    private var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }

    private var activeRestaurant: Restaurant? {
        if let activeId = stores.first?.activeRestaurantId {
            return restaurants.first { $0.id == activeId }
        }
        return restaurants.first
    }

    private var activeRestaurantId: UUID? { activeRestaurant?.id }

    private var complianceScore: Int {
        let alerts = activeAlertsCount
        if alerts == 0 { return 98 }
        return max(72, 98 - alerts * 4)
    }

    private var activeAlertsCount: Int { metrics.activeAlerts }

    private var temperatureAlertsLabel: String {
        activeAlertsCount > 0 ? "Richiede attenzione" : "Nessuna criticità"
    }

    private var openTasksCount: Int { metrics.openTasks }

    private var recordsCount: Int {
        metrics.traceabilityCount + metrics.blastCount
    }

    private func badgeCount(for item: SidebarItem) -> Int? {
        switch item {
        case .scheduling: return countForScheduling
        case .traceability: return countForTraceability
        case .fridges: return countForFridges
        case .cleaningControl: return countForCleaning
        case .blastChilling: return countForBlast
        default: return nil
        }
    }

    private var countForScheduling: Int? {
        metrics.openTasks > 0 ? metrics.openTasks : nil
    }
    private var countForTraceability: Int? {
        metrics.traceabilityCount > 0 ? metrics.traceabilityCount : nil
    }
    private var countForFridges: Int? {
        metrics.activeAlerts > 0 ? metrics.activeAlerts : nil
    }
    private var countForCleaning: Int? {
        metrics.incompleteCleaning > 0 ? metrics.incompleteCleaning : nil
    }
    private var countForBlast: Int? {
        metrics.blastCount > 0 ? metrics.blastCount : nil
    }
    private var countForDocuments: Int? {
        metrics.documentFolders > 0 ? metrics.documentFolders : nil
    }
}
