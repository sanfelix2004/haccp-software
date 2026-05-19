//
//  HACCPManagerApp.swift
//  HACCP Manager
//

import SwiftUI
import SwiftData

@main
struct HACCPManagerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = AppState()
    private let expiryService = TraceabilityExpiryService()
    
    // Explicitly configure model container to ensure persistence
    private var container: ModelContainer
    
    init() {
        // Tema/layout da UserDefaults prima del primo frame (evita flash nero).
        ThemeManager.shared.loadSavedTheme()

        do {
            container = try ModelContainer(
                for: LocalUser.self,
                AppDataStore.self,
                Restaurant.self,
                TemperatureDevice.self,
                TemperatureRecord.self,
                TemperatureAlert.self,
                TemperatureAuditLog.self,
                ChecklistTemplate.self,
                ChecklistItemTemplate.self,
                ChecklistRun.self,
                ChecklistItemResult.self,
                ChecklistAlert.self,
                ChecklistAuditLog.self,
                CleaningArea.self,
                CleaningTask.self,
                FridgeCheckRecord.self,
                ScheduledTask.self,
                TraceabilityRecord.self,
                CleaningRecord.self,
                CleaningCriticality.self,
                BlastChillingRecord.self,
                DefrostRecord.self,
                OilPoint.self,
                OilControlRecord.self,
                OilControlAlert.self,
                ProductionLabelRecord.self,
                GoodsReceivingRecord.self,
                Supplier.self,
                ProductTemplate.self,
                ProductionCategory.self,
                Production.self,
                TraceabilityLink.self,
                TraceabilityLog.self,
                ProductImage.self,
                DocumentFolder.self,
                DocumentItem.self,
                HACCPAuditEvent.self,
                HACCPReportRevision.self,
                HACCPReportSnapshot.self
            )
        } catch {
            fatalError("Failed to initialize SwiftData model container: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active || newPhase == .background else { return }
            let context = container.mainContext
            Task { @MainActor in
                var descriptor = FetchDescriptor<TraceabilityRecord>(
                    predicate: #Predicate { !$0.isArchived },
                    sortBy: [SortDescriptor(\TraceabilityRecord.expiryDate)]
                )
                descriptor.fetchLimit = 2_000
                if let activeRecords = try? context.fetch(descriptor) {
                    _ = expiryService.refreshStatuses(records: activeRecords, modelContext: context)
                }
                if newPhase == .active {
                    if let restaurantId = appState.activeRestaurantId {
                        await DataArchiveService.runIfNeeded(context: context, restaurantId: restaurantId)
                    }
                    await tickReportEngine(modelContext: context)
                }
            }
        }
    }

    /// "Catch-up" del motore report: appena l'app torna in foreground, verifica se
    /// sono state attraversate frontiere giornaliere/settimanali/mensili/annuali e,
    /// in caso, esegue la pipeline completa senza richiedere azioni manuali.
    @MainActor
    private func tickReportEngine(modelContext: ModelContext) async {
        guard let restaurantId = appState.activeRestaurantId,
              let userId = appState.currentUserId else { return }
        let restaurants = (try? modelContext.fetch(FetchDescriptor<Restaurant>())) ?? []
        let users = (try? modelContext.fetch(FetchDescriptor<LocalUser>())) ?? []
        guard let restaurant = restaurants.first(where: { $0.id == restaurantId }),
              let user = users.first(where: { $0.id == userId }) else { return }

        await HACCPReportScheduler.shared.tickIfNeeded(
            restaurant: restaurant,
            user: user,
            modelContext: modelContext
        )
        HACCPReportEngine.shared.refreshStats(restaurantId: restaurant.id, in: modelContext)
    }
}
