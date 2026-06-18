import SwiftUI
import SwiftData

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme

    private let toolModules: [(item: SidebarItem, description: String, icon: String)] = [
        (.checklist, "Controlli periodici", "checklist"),
        (.documents, "Report e archivio PDF", "folder.fill"),
        (.analytics, "Andamento e statistiche", "chart.bar.fill"),
        (.alerts, "Avvisi da gestire", "bell.badge.fill")
    ]

    private let haccpDashboardModules: [(item: SidebarItem, description: String, icon: String)] = [
        (.traceability, "Prodotti, lotti, fornitori", "archivebox.fill"),
        (.fridges, "Temperature e allarmi", "thermometer.medium"),
        (.cleaningControl, "Piani pulizia", "sparkles"),
        (.blastChilling, "Abbattimento termico", "wind.snow"),
        (.expiryControl, "Scadenze prodotti", "calendar.badge.exclamationmark"),
        (.defrost, "Decongelamenti", "snowflake"),
        (.oilControl, "Olio frittura", "drop.fill"),
        (.productionLabels, "Etichette produzione", "tag.fill"),
        (.goodsReceiving, "Ricezione merci", "shippingbox.fill")
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
                HStack(alignment: .top, spacing: 12) {
                    DashboardHeaderView(
                        user: currentUser,
                        restaurant: activeRestaurant,
                        dateTimeText: viewModel.formattedDateTime,
                        systemStateMessage: "Sistema pronto · \(activeRestaurant?.name ?? "HACCP")"
                    )
                    ModuleHelpButton(help: ModuleHelpLibrary.sidebar(.dashboard), size: 44)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                statsRow
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                DashboardCardView(title: "Moduli HACCP", subtitle: "Accesso rapido alle registrazioni") {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(visibleHaccpModules, id: \.item) { row in
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

                DashboardCardView(title: "Strumenti", subtitle: "Checklist, documenti, grafici e avvisi") {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(visibleToolModules, id: \.item) { row in
                            Button {
                                HapticManager.shared.selection()
                                appState.pendingSidebarNavigation = row.item
                            } label: {
                                ModuleTileView(
                                    title: row.item.rawValue,
                                    icon: row.icon,
                                    description: row.description,
                                    badge: toolBadge(for: row.item)
                                )
                            }
                            .buttonStyle(PremiumPressButtonStyle())
                        }
                    }
                }

                if SidebarItem.history.isAccessible(by: permissions) {
                    DashboardCardView(title: "Storia", subtitle: "Archivio registrazioni centralizzato") {
                        archiveTile(
                            title: "Storia",
                            icon: "clock.arrow.circlepath",
                            description: "Tutte le registrazioni HACCP",
                            badge: nil,
                            target: .history
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
                title: "Avvisi attivi",
                value: "\(activeAlertsCount)",
                subtitle: activeAlertsCount > 0 ? "Da gestire" : "Tutto ok",
                icon: "bell.badge.fill",
                accent: activeAlertsCount > 0 ? theme.colorError : theme.colorSuccess
            )
            StatCard(
                title: "Checklist aperte",
                value: "\(openTasksCount)",
                subtitle: "Da completare",
                icon: "checklist",
                accent: theme.colorInfo
            )
            StatCard(
                title: "Registrazioni",
                value: "\(recordsCount)",
                subtitle: "Oggi nel sistema",
                icon: "doc.text.fill",
                accent: theme.colorPrimary
            )
            StatCard(
                title: "Documenti",
                value: "\(metrics.documentItems)",
                subtitle: "In archivio",
                icon: "folder.fill",
                accent: theme.colorInfo
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

    private var permissions: UserPermissions {
        currentUser.permissions
    }

    private var visibleHaccpModules: [(item: SidebarItem, description: String, icon: String)] {
        haccpDashboardModules.filter { $0.item.isAccessible(by: permissions) }
    }

    private var visibleToolModules: [(item: SidebarItem, description: String, icon: String)] {
        toolModules.filter { $0.item.isAccessible(by: permissions) }
    }

    private var activeRestaurant: Restaurant? {
        if let activeId = stores.first?.activeRestaurantId {
            return restaurants.first { $0.id == activeId }
        }
        return restaurants.first
    }

    private var activeRestaurantId: UUID? { activeRestaurant?.id }

    private var recordsCount: Int { metrics.todayRecords }

    private func toolBadge(for item: SidebarItem) -> Int? {
        switch item {
        case .alerts:
            return activeAlertsCount > 0 ? activeAlertsCount : nil
        case .documents:
            return metrics.documentItems > 0 ? metrics.documentItems : nil
        default:
            return nil
        }
    }

    private var activeAlertsCount: Int { metrics.activeAlerts }

    private var openTasksCount: Int { metrics.openTasks }

    private func badgeCount(for item: SidebarItem) -> Int? {
        switch item {
        case .checklist: return countForChecklist
        case .traceability: return countForTraceability
        case .fridges: return countForFridges
        case .cleaningControl: return countForCleaning
        case .blastChilling: return countForBlast
        default: return nil
        }
    }

    private var countForChecklist: Int? {
        metrics.openTasks > 0 ? metrics.openTasks : nil
    }
    private var countForTraceability: Int? {
        metrics.traceabilityCount > 0 ? metrics.traceabilityCount : nil
    }
    private var countForFridges: Int? {
        metrics.temperatureAlerts > 0 ? metrics.temperatureAlerts : nil
    }
    private var countForCleaning: Int? {
        metrics.incompleteCleaning > 0 ? metrics.incompleteCleaning : nil
    }
    private var countForBlast: Int? {
        metrics.blastCount > 0 ? metrics.blastCount : nil
    }
}
