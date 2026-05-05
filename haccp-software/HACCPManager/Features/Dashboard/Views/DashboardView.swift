import SwiftUI
import SwiftData

struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    private let haccpDashboardModules: [(item: SidebarItem, description: String, icon: String)] = [
        (.traceability, "Prodotti, lotti, fornitori e stato", "archivebox.fill"),
        (.fridges, "Temperature e allarmi fuori range", "thermometer.medium"),
        (.cleaningControl, "Piani pulizia e completamento", "sparkles"),
        (.blastChilling, "Registrazioni abbattimento termico", "wind.snow"),
        (.scheduling, "Attività periodiche e scadenze", "calendar.badge.clock"),
        (.expiryControl, "Monitoraggio scadenze (in arrivo)", "calendar.badge.exclamationmark"),
        (.defrost, "Storico decongelamenti", "snowflake"),
        (.oilControl, "Controlli olio frittura", "drop.fill"),
        (.productionLabels, "Etichette e tracciabilità produzione", "tag.fill"),
        (.goodsReceiving, "Conformità in ingresso merci", "shippingbox.fill"),
        (.moduleTimer, "Timer operativi (in arrivo)", "timer")
    ]
    @Query private var users: [LocalUser]
    @Query private var restaurants: [Restaurant]
    @Query private var stores: [AppDataStore]
    @Query private var scheduledTasks: [ScheduledTask]
    @Query private var traceabilityRecords: [TraceabilityRecord]
    @Query private var temperatureAlerts: [TemperatureAlert]
    @Query private var cleaningRecords: [CleaningRecord]
    @Query private var blastRecords: [BlastChillingRecord]
    @Query private var defrostRecords: [DefrostRecord]
    @Query private var oilRecords: [OilControlRecord]
    @Query private var labelRecords: [ProductionLabelRecord]
    @Query private var goodsRecords: [GoodsReceipt]
    @Query private var documentFolders: [DocumentFolder]

    @StateObject private var viewModel: DashboardViewModel
    @State private var appeared = false
    
    init() {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(provider: DashboardDataProvider()))
    }

    var activeRestaurant: Restaurant? {
        if let activeId = stores.first?.activeRestaurantId {
            return restaurants.first { $0.id == activeId }
        }
        return restaurants.first
    }

    private var activeRestaurantId: UUID? {
        activeRestaurant?.id
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                DashboardHeaderView(
                    user: currentUser,
                    restaurant: activeRestaurant,
                    dateTimeText: viewModel.formattedDateTime,
                    systemStateMessage: "Sistema pronto per \(activeRestaurant?.name ?? "il tuo ristorante")"
                )
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
                .animation(ThemeManager.shared.spring, value: appeared)

                DashboardCardView(title: "Moduli HACCP") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(haccpDashboardModules, id: \.item) { row in
                            Button {
                                appState.pendingSidebarNavigation = row.item
                            } label: {
                                moduleCard(
                                    title: row.item.rawValue,
                                    icon: row.icon,
                                    description: row.description,
                                    badge: badgeCount(for: row.item)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                DashboardCardView(title: "Sistema e archivi") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        Button {
                            appState.pendingSidebarNavigation = .documents
                        } label: {
                            moduleCard(title: "Documenti", icon: "folder.fill", description: "Report e cartelle HACCP", badge: countForDocuments)
                        }
                        .buttonStyle(.plain)
                        Button {
                            appState.pendingSidebarNavigation = .history
                        } label: {
                            moduleCard(title: "Storia", icon: "clock.arrow.circlepath", description: "Archivio centralizzato", badge: nil)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
                .animation(ThemeManager.shared.spring.delay(0.2), value: appeared)
            }
            .padding(24)
        }
        .background(ThemeManager.shared.background.ignoresSafeArea())
        .navigationTitle("Dashboard")
        .onAppear {
            withAnimation {
                appeared = true
            }
            viewModel.reload()
        }
    }

    private var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }

    private func badgeCount(for item: SidebarItem) -> Int? {
        switch item {
        case .scheduling: return countForScheduling
        case .traceability: return countForTraceability
        case .fridges: return countForFridges
        case .cleaningControl: return countForCleaning
        case .blastChilling: return countForBlast
        case .defrost: return countForDefrost
        case .oilControl: return countForOil
        case .productionLabels: return countForLabels
        case .goodsReceiving: return countForGoods
        default: return nil
        }
    }

    private var countForScheduling: Int? {
        guard let rid = activeRestaurantId else { return nil }
        let count = scheduledTasks.filter { $0.restaurantId == rid && !$0.isCompleted }.count
        return count > 0 ? count : nil
    }
    private var countForTraceability: Int? {
        guard let rid = activeRestaurantId else { return nil }
        let count = traceabilityRecords.filter { $0.restaurantId == rid }.count
        return count > 0 ? count : nil
    }
    private var countForFridges: Int? {
        guard let rid = activeRestaurantId else { return nil }
        let count = temperatureAlerts.filter { $0.restaurantId == rid && $0.isActive }.count
        return count > 0 ? count : nil
    }
    private var countForCleaning: Int? {
        guard let rid = activeRestaurantId else { return nil }
        let count = cleaningRecords.filter { $0.restaurantId == rid && !$0.completed }.count
        return count > 0 ? count : nil
    }
    private var countForBlast: Int? {
        guard let rid = activeRestaurantId else { return nil }
        let count = blastRecords.filter { $0.restaurantId == rid }.count
        return count > 0 ? count : nil
    }
    private var countForDefrost: Int? {
        guard let rid = activeRestaurantId else { return nil }
        let count = defrostRecords.filter { $0.restaurantId == rid }.count
        return count > 0 ? count : nil
    }
    private var countForOil: Int? {
        guard let rid = activeRestaurantId else { return nil }
        let count = oilRecords.filter { $0.restaurantId == rid }.count
        return count > 0 ? count : nil
    }
    private var countForLabels: Int? {
        guard let rid = activeRestaurantId else { return nil }
        let count = labelRecords.filter { $0.restaurantId == rid }.count
        return count > 0 ? count : nil
    }
    private var countForGoods: Int? {
        guard let rid = activeRestaurantId else { return nil }
        let count = goodsRecords.filter { $0.restaurantId == rid }.count
        return count > 0 ? count : nil
    }
    private var countForDocuments: Int? {
        guard let rid = activeRestaurantId else { return nil }
        let count = documentFolders.filter { $0.restaurantId == rid }.count
        return count > 0 ? count : nil
    }

    private func moduleCard(title: String, icon: String, description: String, badge: Int?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(.red)
                Spacer()
                if let badge {
                    Text("\(badge)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.3))
                        .cornerRadius(8)
                }
            }
            Text(title).foregroundColor(.white).font(.headline)
            Text(description).foregroundColor(.gray).font(.caption)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}
