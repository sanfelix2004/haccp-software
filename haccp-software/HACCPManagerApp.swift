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
                FridgeCheckRecord.self,
                ScheduledTask.self,
                TraceabilityRecord.self,
                CleaningRecord.self,
                BlastChillingRecord.self,
                DefrostRecord.self,
                OilControlRecord.self,
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
                DocumentItem.self
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
            if let all = try? context.fetch(FetchDescriptor<TraceabilityRecord>()) {
                _ = expiryService.refreshStatuses(records: all, modelContext: context)
            }
        }
    }
}
