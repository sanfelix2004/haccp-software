import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
final class SettingsStorageService {
    static let shared = SettingsStorageService()
    
    private init() {}
    
    private var modelContext: ModelContext?
    private var dataStore: AppDataStore?
    
    var restaurant = RestaurantSettings()
    var haccp = HACCPSettings()
    var security = SecuritySettings()
    var notifications = NotificationSettings()
    var appearance = AppearanceSettings()
    var printer = LabelPrinterSettings()
    
    func setup(with context: ModelContext) {
        self.modelContext = context
        fetchOrCreateStore()
    }
    
    private func fetchOrCreateStore() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<AppDataStore>(predicate: #Predicate { $0.id == "GLOBAL_SETTINGS" })
        
        if let existing = try? context.fetch(descriptor).first {
            self.dataStore = existing
            loadFromStore(existing)
        } else {
            let newStore = AppDataStore()
            context.insert(newStore)
            self.dataStore = newStore
            saveAll()
        }
    }
    
    private func loadFromStore(_ store: AppDataStore) {
        let decoder = JSONDecoder()
        
        if let data = store.restaurantData { restaurant = (try? decoder.decode(RestaurantSettings.self, from: data)) ?? restaurant }
        if let data = store.haccpData { haccp = (try? decoder.decode(HACCPSettings.self, from: data)) ?? haccp }
        if let data = store.securityData { security = (try? decoder.decode(SecuritySettings.self, from: data)) ?? security }
        if let data = store.notificationData { notifications = (try? decoder.decode(NotificationSettings.self, from: data)) ?? notifications }
        if let data = store.printerData { printer = (try? decoder.decode(LabelPrinterSettings.self, from: data)) ?? printer }
    }
    
    func saveAll() {
        guard let store = dataStore else { return }
        let encoder = JSONEncoder()
        
        store.restaurantData = try? encoder.encode(restaurant)
        store.haccpData = try? encoder.encode(haccp)
        store.securityData = try? encoder.encode(security)
        store.notificationData = try? encoder.encode(notifications)
        store.printerData = try? encoder.encode(printer)
        
        try? modelContext?.save()
    }
    
    func wipe() {
        restaurant = RestaurantSettings()
        haccp = HACCPSettings()
        security = SecuritySettings()
        notifications = NotificationSettings()
        appearance = AppearanceSettings()
        printer = LabelPrinterSettings()
        dataStore = nil
    }
}
