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
    
    // Explicitly configure model container to ensure persistence
    private var container: ModelContainer
    
    init() {
        CoreDataLoggingSuppressor.apply()

        // Tema/layout da UserDefaults prima del primo frame (evita flash nero).
        ThemeManager.shared.loadSavedTheme()

        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }

        do {
            container = try Self.makeModelContainer()
        } catch {
            // Store corrotto dopo migrazione fallita (es. nuovo campo obbligatorio): ricrea database locale.
            Self.removePersistentStoreFiles()
            do {
                container = try Self.makeModelContainer()
            } catch {
                fatalError("Failed to initialize SwiftData model container: \(error)")
            }
        }
    }

    private static func makeModelContainer() throws -> ModelContainer {
        try ModelContainer(
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
            DefrostCriticality.self,
            OilPoint.self,
            OilControlRecord.self,
            OilControlAlert.self,
            ProductionLabelRecord.self,
            GoodsReceivingRecord.self,
            Supplier.self,
            ProductTemplate.self,
            ProductionCategory.self,
            Production.self,
            ProduzioneBatch.self,
            IngredienteTracciato.self,
            ProductionIncomingIngredient.self,
            LottoFoto.self,
            LottoFotoProductionLink.self,
            NonConformitaRicezione.self,
            TraceabilityLink.self,
            TraceabilityLog.self,
            ProductImage.self,
            DocumentFolder.self,
            DocumentItem.self,
            HACCPAuditEvent.self,
            HACCPReportRevision.self,
            HACCPReportSnapshot.self
        )
    }

    private static func removePersistentStoreFiles() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: appSupport,
            includingPropertiesForKeys: nil
        ) else { return }
        for url in files where url.lastPathComponent.hasPrefix("default.store") {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(ActiveBlastChillingManager.shared)
                .environmentObject(ActiveDefrostManager.shared)
                .environmentObject(ClabelPrinterManager.shared)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            let context = container.mainContext
            let restaurantId = appState.activeRestaurantId
            Task(priority: .utility) { @MainActor in
                await MainThreadYield.beforeHeavyWork()
                guard !Task.isCancelled else { return }

                if let restaurantId {
                    var descriptor = FetchDescriptor<TraceabilityRecord>(
                        predicate: #Predicate { record in
                            record.restaurantId == restaurantId && !record.isArchived
                        },
                        sortBy: [SortDescriptor(\TraceabilityRecord.expiryDate)]
                    )
                    descriptor.fetchLimit = PerformanceConfig.traceabilityActiveFetchLimit
                    if let activeRecords = try? context.fetch(descriptor) {
                        await MainThreadYield.betweenFetchPhases()
                        _ = TraceabilityExpiryService().refreshStatuses(records: activeRecords, modelContext: context)
                    }
                }

                DocumentArchivePurgeService.consumeMarkerAndPurgeIfNeeded(modelContext: context)
                await MainThreadYield.betweenFetchPhases()
                SchedulingToChecklistMigrationService.migrateIfNeeded(modelContext: context)
                if let restaurantId {
                    await DataArchiveService.runIfNeeded(modelContainer: container, restaurantId: restaurantId)
                }
                ClabelPrinterManager.shared.reconnectIfSaved()
                await tickMonthlyArchive(modelContext: context)
            }
        }
    }

    /// PDF mensili incrementali e backup iCloud: aggiornamento all'apertura dell'app.
    @MainActor
    private func tickMonthlyArchive(modelContext: ModelContext) async {
        guard let restaurantId = appState.activeRestaurantId,
              let userId = appState.currentUserId else { return }
        let restaurants = (try? modelContext.fetch(FetchDescriptor<Restaurant>())) ?? []
        let users = (try? modelContext.fetch(FetchDescriptor<LocalUser>())) ?? []
        guard let restaurant = restaurants.first(where: { $0.id == restaurantId }),
              let user = users.first(where: { $0.id == userId }) else { return }

        await DocumentArchivePurgeService.regenerateArchiveIfNeeded(
            modelContext: modelContext,
            restaurant: restaurant,
            user: user
        )
        await HACCPReportScheduler.shared.tickIfNeeded(
            restaurant: restaurant,
            user: user,
            modelContext: modelContext
        )
    }
}
