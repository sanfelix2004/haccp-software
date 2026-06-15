import SwiftUI
import SwiftData

enum SidebarItem: String, Identifiable {
    case dashboard = "Dashboard"
    case traceability = "Tracciabilità"
    case fridges = "Frigoriferi"
    case cleaningControl = "Controllo pulizia"
    case blastChilling = "Abbattimento"
    case scheduling = "Programmazione"
    case expiryControl = "Controllo scadenze"
    case defrost = "Decongelamento"
    case oilControl = "Controllo olio"
    case productionLabels = "Etichette di produzione"
    case goodsReceiving = "Ricezione merci"
    case checklist = "Checklist"
    case history = "Storia"
    case documents = "Documenti"
    case analytics = "Grafici"
    case alerts = "Avvisi"
    case users = "Utenti"
    case settings = "Impostazioni"

    var id: String { rawValue }

    /// Moduli HACCP principali (ordine ufficiale).
    static let haccpModulesInOrder: [SidebarItem] = [
        .traceability, .fridges, .cleaningControl, .blastChilling, .scheduling,
        .expiryControl, .defrost, .oilControl, .productionLabels, .goodsReceiving,
        .checklist
    ]

    static let toolsInOrder: [SidebarItem] = [
        .documents, .analytics, .history, .alerts, .users, .settings
    ]

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .scheduling: return "calendar.badge.clock"
        case .traceability: return "archivebox.fill"
        case .fridges: return "thermometer.medium"
        case .cleaningControl: return "sparkles"
        case .blastChilling: return "wind.snow"
        case .defrost: return "snowflake"
        case .oilControl: return "drop.fill"
        case .productionLabels: return "tag.fill"
        case .goodsReceiving: return "shippingbox.fill"
        case .checklist: return "checklist"
        case .expiryControl: return "calendar.badge.exclamationmark"
        case .history: return "clock.arrow.circlepath"
        case .documents: return "folder.fill"
        case .analytics: return "chart.bar.fill"
        case .alerts: return "bell.badge.fill"
        case .users: return "person.2.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct DashboardRootView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var restaurants: [Restaurant]
    @Query private var stores: [AppDataStore]
    
    @State private var selectedItem: SidebarItem? = .dashboard
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var detailNavigationPath = NavigationPath()
    @State private var showCreateUserFromSidebar = false
    @State private var showMasterAuthForCreate = false
    private let documentsService = DocumentsService()
    private let productionLibraryService = ProductionLibraryService()
    private let oilControlService = OilControlService()
    
    var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }
    
    var activeRestaurant: Restaurant? {
        if let activeId = appState.activeRestaurantId {
            return restaurants.first { $0.id == activeId }
        }
        return restaurants.first
    }
    
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            PremiumSidebarView(
                selectedItem: $selectedItem,
                activeRestaurant: activeRestaurant,
                restaurantsCount: restaurants.count,
                isMaster: currentUser?.role == .master,
                onSwitchRestaurant: {
                    withAnimation(theme.spring) { appState.activeRestaurantId = nil }
                },
                onLogout: { appState.logout() }
            )
            .padding(floatingSidebarPadding)
            .background {
                if theme.sidebarStyle == .floating {
                    RoundedRectangle(cornerRadius: theme.spacing.cornerXL, style: .continuous)
                        .fill(theme.colorSurface)
                        .shadow(
                            color: theme.shadows.elevated.color,
                            radius: theme.shadows.elevated.radius,
                            y: theme.shadows.elevated.y
                        )
                }
            }
            .navigationTitle("")
        } detail: {
            ZStack {
                theme.colorBackground.ignoresSafeArea()

                if let selectedItem = selectedItem {
                    NavigationStack(path: $detailNavigationPath) {
                        detailView(for: selectedItem)
                            .scrollContentBackground(.hidden)
                    }
                    .id(selectedItem.id)
                } else {
                    VStack(spacing: theme.spacing.lg) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(theme.colorTextSecondary)
                        Text("Seleziona un modulo")
                            .font(theme.typography.title3)
                            .foregroundStyle(theme.colorTextPrimary)
                    }
                    .transition(.opacity)
                }
            }
        }
        .onChange(of: selectedItem) { oldItem, newItem in
            guard oldItem?.id != newItem?.id else { return }
            detailNavigationPath = NavigationPath()
        }
        .onChange(of: appState.navigateToGoodsReceiving) { _, go in
            if go {
                selectedItem = .goodsReceiving
                appState.navigateToGoodsReceiving = false
            }
        }
        .onChange(of: appState.pendingSidebarNavigation) { _, target in
            guard let target else { return }
            selectedItem = target
            appState.pendingSidebarNavigation = nil
        }
        .onChange(of: appState.activeRestaurantId) { _, _ in
            ensureRestaurantDefaults()
        }
        .sheet(isPresented: $showCreateUserFromSidebar) {
            CreateUserView()
        }
        .fullScreenCover(isPresented: $showMasterAuthForCreate) {
            if let master = users.first(where: { $0.role == .master }) {
                MasterAuthOverlay(
                    master: master,
                    operation: .createUser,
                    onAuthorized: {
                        showMasterAuthForCreate = false
                        showCreateUserFromSidebar = true
                    },
                    onCancel: {
                        showMasterAuthForCreate = false
                    }
                ) { EmptyView() }
            }
        }
        .onAppear {
            ensureRestaurantDefaults()
        }
    }

    private var floatingSidebarPadding: EdgeInsets {
        theme.sidebarStyle == .floating
            ? EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 0)
            : EdgeInsets()
    }

    private func ensureRestaurantDefaults() {
        guard
            let rid = appState.activeRestaurantId,
            let user = currentUser
        else { return }

        Task { @MainActor in
            let ridCapture = rid
            var folderDescriptor = FetchDescriptor<DocumentFolder>(
                predicate: #Predicate { $0.restaurantId == ridCapture }
            )
            folderDescriptor.fetchLimit = 200
            let folders = (try? modelContext.fetch(folderDescriptor)) ?? []

            var itemDescriptor = FetchDescriptor<DocumentItem>(
                predicate: #Predicate { $0.restaurantId == ridCapture }
            )
            itemDescriptor.fetchLimit = 500
            let items = (try? modelContext.fetch(itemDescriptor)) ?? []

            var categoryDescriptor = FetchDescriptor<ProductionCategory>(
                predicate: #Predicate { $0.restaurantId == ridCapture }
            )
            categoryDescriptor.fetchLimit = 100
            let categories = (try? modelContext.fetch(categoryDescriptor)) ?? []

            var productionDescriptor = FetchDescriptor<Production>(
                predicate: #Predicate { $0.restaurantId == ridCapture }
            )
            productionDescriptor.fetchLimit = 300
            let productions = (try? modelContext.fetch(productionDescriptor)) ?? []

            var oilDescriptor = FetchDescriptor<OilPoint>(
                predicate: #Predicate { $0.restaurantId == ridCapture }
            )
            oilDescriptor.fetchLimit = 50
            let oilPoints = (try? modelContext.fetch(oilDescriptor)) ?? []

            documentsService.ensureDefaultFolders(
                restaurantId: rid,
                user: user,
                existingFolders: folders,
                existingItems: items,
                modelContext: modelContext
            )
            productionLibraryService.ensureDefaults(
                restaurantId: rid,
                categories: categories,
                productions: productions,
                modelContext: modelContext
            )
            oilControlService.ensureDefaultPoints(
                restaurantId: rid,
                user: user,
                existingPoints: oilPoints,
                modelContext: modelContext
            )
        }
    }
    
    @ViewBuilder
    private func detailView(for item: SidebarItem) -> some View {
        switch item {
        case .dashboard:
            DashboardView()
        case .scheduling:
            SchedulingView()
        case .traceability:
            TraceabilityView()
        case .fridges:
            FridgesView()
        case .cleaningControl:
            CleaningControlView()
        case .blastChilling:
            BlastChillingView()
        case .expiryControl:
            ExpiryControlView()
        case .defrost:
            DefrostView()
        case .oilControl:
            OilControlView()
        case .productionLabels:
            ProductionLabelsView()
        case .goodsReceiving:
            GoodsReceivingView()
        case .checklist:
            ChecklistView()
        case .history:
            HistoryView()
        case .documents:
            DocumentsView()
        case .analytics:
            AnalyticsView()
        case .alerts:
            AlertsView()
        case .users:
            if currentUser?.role == .master {
                UsersManagementView()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 56, weight: .medium))
                        .foregroundStyle(theme.colorPrimary)
                    Text("Accesso riservato")
                        .font(theme.typography.title3)
                        .foregroundStyle(theme.colorTextPrimary)
                    Text("Solo il responsabile può accedere alla gestione dei collaboratori.")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colorTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Collaboratori")
            }
        case .settings:
            SettingsView()
        }
    }
}
