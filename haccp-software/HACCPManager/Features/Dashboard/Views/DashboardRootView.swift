import SwiftUI
import SwiftData

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case scheduling = "Programmazione"
    case traceability = "Tracciabilita"
    case fridges = "Frigoriferi"
    case cleaningControl = "Controllo pulizia"
    case blastChilling = "Abbattimento"
    case defrost = "Decongelamento"
    case oilControl = "Controllo olio"
    case productionLabels = "Etichette"
    case goodsReceiving = "Ricezione merci"
    case documents = "Documenti"
    case history = "Storia"
    case analytics = "Grafici"
    case alerts = "Alert"
    case users = "Utenti"
    case settings = "Impostazioni"
    
    var id: String { self.rawValue }
    
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
        case .documents: return "folder.fill"
        case .history: return "clock.arrow.circlepath"
        case .analytics: return "chart.xyaxis.line"
        case .alerts: return "bell.badge.fill"
        case .users: return "person.2.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct DashboardRootView: View {
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var restaurants: [Restaurant]
    @Query private var stores: [AppDataStore]
    
    @State private var selectedItem: SidebarItem? = .dashboard
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showCreateUserFromSidebar = false
    @State private var showMasterAuthForCreate = false
    
    var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }
    
    var activeRestaurant: Restaurant? {
        if let activeId = appState.activeRestaurantId {
            return restaurants.first { $0.id == activeId }
        }
        return restaurants.first
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                // Restaurant Header in Sidebar
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        if let logoData = activeRestaurant?.logoData, let uiImage = UIImage(data: logoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 54, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.1))
                                .frame(width: 54, height: 54)
                                .overlay(
                                    Image(systemName: "house.fill")
                                        .foregroundColor(.red)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activeRestaurant?.name ?? "HACCP")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(activeRestaurant?.city ?? "Manager")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .tracking(1)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .onTapGesture {
                        if restaurants.count > 1 {
                            HapticManager.shared.selection()
                            withAnimation { appState.activeRestaurantId = nil }
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                        .padding(.top, 8)
                }
                .background(ThemeManager.shared.surface)
                
                List(selection: $selectedItem) {
                    Section {
                        ForEach(SidebarItem.allCases) { item in
                            // Filter users section for non-master
                            if item == .users {
                                if currentUser?.role == .master {
                                    NavigationLink(value: item) {
                                        Label(item.rawValue, systemImage: item.icon)
                                    }
                                }
                            } else {
                                NavigationLink(value: item) {
                                    Label(item.rawValue, systemImage: item.icon)
                                }
                            }
                        }
                    } header: {
                        Text("Menu Principale")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.gray)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                
                // Native Logout Button at the bottom
                VStack(spacing: 0) {
                    Divider().background(Color.white.opacity(0.1))
                    Button(action: { appState.logout() }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Esci dal sistema")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(16)
                }
                .background(ThemeManager.shared.surface)
            }
            .background(ThemeManager.shared.surface)
            .navigationTitle(activeRestaurant?.name ?? AppVersionService.appName)
        } detail: {
            ZStack {
                ThemeManager.shared.background.ignoresSafeArea()
                
                if let selectedItem = selectedItem {
                    NavigationStack {
                        detailView(for: selectedItem)
                            .id(selectedItem.id) // Force refresh for transition
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity
                            ))
                            .background(ThemeManager.shared.background)
                            .scrollContentBackground(.hidden)
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedItem)
                } else {
                    Text("Seleziona una voce dal menu")
                        .foregroundColor(ThemeManager.shared.textSecondary)
                        .transition(.opacity)
                }
            }
        }
        .onChange(of: appState.navigateToGoodsReceiving) { _, go in
            if go {
                selectedItem = .goodsReceiving
                appState.navigateToGoodsReceiving = false
            }
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
        case .defrost:
            DefrostView()
        case .oilControl:
            OilControlView()
        case .productionLabels:
            ProductionLabelsView()
        case .goodsReceiving:
            GoodsReceivingView()
        case .documents:
            DocumentsView()
        case .history:
            HistoryView()
        case .analytics:
            AnalyticsView()
        case .alerts:
            AlertsView()
        case .users:
            if currentUser?.role == .master {
                UsersManagementView()
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    Text("Accesso Negato")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Solo il MASTER può accedere alla gestione collaboratori.")
                        .foregroundColor(.gray)
                }
                .navigationTitle("Gestione Staff")
            }
        case .settings:
            SettingsView()
        }
    }
}
