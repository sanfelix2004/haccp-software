import SwiftUI
import Combine
import SwiftData

class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUserId: UUID? = nil
    @Published var activeRestaurantId: UUID? = nil
    @Published var showSplash: Bool = true
    @Published var showMasterFirstAccessIntro: Bool = false
    
    @Published var showRestaurantOnboarding: Bool = false
    @Published var isLoading: Bool = false
    
    private let firstAccessPrefix = "master_first_access_pending_"
    
    func login(userId: UUID) {
        currentUserId = userId
        isAuthenticated = true
    }
    
    func logout() {
        currentUserId = nil
        activeRestaurantId = nil
        isAuthenticated = false
        showRestaurantOnboarding = false
    }
    
    @MainActor
    func switchRestaurant(id: UUID, modelContext: ModelContext) {
        isLoading = true
        activeRestaurantId = id
        
        // Sync with persistence
        let descriptor = FetchDescriptor<AppDataStore>()
        if let store = try? modelContext.fetch(descriptor).first {
            store.activeRestaurantId = id
            try? modelContext.save()
        }
        
        // Brief artificial delay for premium loading feel
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.isLoading = false
        }
    }
    
    func resetSystem() {
        logout()
    }
    
    @MainActor
    func factoryReset(modelContext: ModelContext) {
        // 1. Terminate all sessions and clear in-memory state
        logout()
        currentUserId = nil
        activeRestaurantId = nil
        isAuthenticated = false
        showSplash = false
        showMasterFirstAccessIntro = false
        showRestaurantOnboarding = false
        
        // 2. Clear SwiftData - Bulk deletion
        try? modelContext.delete(model: LocalUser.self)
        try? modelContext.delete(model: Restaurant.self)
        try? modelContext.delete(model: AppDataStore.self)
        
        // 3. Clear SwiftData - Manual cleanup (Fallback for potential SwiftData inconsistencies)
        do {
            let restaurants = try modelContext.fetch(FetchDescriptor<Restaurant>())
            for restaurant in restaurants { modelContext.delete(restaurant) }
            
            let users = try modelContext.fetch(FetchDescriptor<LocalUser>())
            for user in users { modelContext.delete(user) }
            
            let stores = try modelContext.fetch(FetchDescriptor<AppDataStore>())
            for store in stores { modelContext.delete(store) }
            
            try modelContext.save()
        } catch {
            print("Factory Reset: SwiftData cleanup error: \(error)")
        }
        
        // 4. Persistence synchronization
        try? modelContext.save()
        
        // 5. Clear Service singletons and caches
        SettingsStorageService.shared.wipe()
        
        // 6. Hard Reset UserDefaults (Domain-wide)
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
        
        // 7. Clear any lingering specific keys (Just in case)
        UserDefaults.standard.removeObject(forKey: "active_restaurant_id")
        UserDefaults.standard.removeObject(forKey: "current_user_id")
        
        // 8. Force UI refresh
        self.objectWillChange.send()
    }

    func markMasterFirstAccessPending(masterId: UUID) {
        UserDefaults.standard.set(true, forKey: firstAccessPrefix + masterId.uuidString)
    }
    
    func evaluateMasterFirstAccess(masterId: UUID) {
        showMasterFirstAccessIntro = UserDefaults.standard.bool(forKey: firstAccessPrefix + masterId.uuidString)
    }
    
    func completeMasterFirstAccessIntro(masterId: UUID) {
        UserDefaults.standard.set(false, forKey: firstAccessPrefix + masterId.uuidString)
        showMasterFirstAccessIntro = false
        showRestaurantOnboarding = true
    }
}
