//
//  haccp_softwareApp.swift
//  haccp-software
//

import SwiftUI
import SwiftData

@main
struct haccp_softwareApp: App {
    @StateObject private var appState = AppState()
    
    // Explicitly configure model container to ensure persistence
    private var container: ModelContainer
    
    init() {
        do {
            container = try ModelContainer(for: LocalUser.self, AppDataStore.self, Restaurant.self)
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
