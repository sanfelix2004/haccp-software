//
//  HACCPManagerApp.swift
//  HACCP Manager
//

import SwiftUI
import SwiftData

@main
struct HACCPManagerApp: App {
    @StateObject private var appState = AppState()
    
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
    }
}
