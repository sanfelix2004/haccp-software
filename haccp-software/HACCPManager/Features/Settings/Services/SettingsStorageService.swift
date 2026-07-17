import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
final class SettingsStorageService {
    static let shared = SettingsStorageService()

    private var modelContext: ModelContext?
    private var dataStore: AppDataStore?
    private(set) var isHydratedFromSwiftData = false
    private let saveDebouncer = DebouncedMainActorTask(milliseconds: 450)

    var restaurant = RestaurantSettings()
    var haccp = HACCPSettings()
    var security = SecuritySettings()
    var notifications = NotificationSettings()
    var appearance = AppearanceSettings()
    var printer = LabelPrinterSettings()

    private init() {
        bootstrapAppearanceFromDisk()
    }

    /// Carica tema/layout da UserDefaults prima del primo render (sincrono).
    func bootstrapAppearanceFromDisk() {
        if ThemeStorage.shared.hasPersistedAppearance {
            appearance = ThemeStorage.shared.restoreAppearance()
        } else {
            appearance = AppearanceSettings()
            appearance.normalizeStoredPreferences()
            ThemeStorage.shared.mirror(appearance)
        }
    }

    /// Chiamare appena `ModelContext` è disponibile (ContentView / App), non solo da Impostazioni.
    func setup(with context: ModelContext) {
        guard modelContext == nil || modelContext !== context else {
            if !isHydratedFromSwiftData {
                fetchOrCreateStore()
            }
            return
        }
        modelContext = context
        fetchOrCreateStore()
    }

    private func fetchOrCreateStore() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<AppDataStore>(predicate: #Predicate { $0.id == "GLOBAL_SETTINGS" })

        if let existing = try? context.fetch(descriptor).first {
            dataStore = existing
            loadFromStore(existing)
        } else {
            let newStore = AppDataStore()
            context.insert(newStore)
            dataStore = newStore
            saveAllImmediately()
        }
        isHydratedFromSwiftData = true
    }

    private func loadFromStore(_ store: AppDataStore) {
        let decoder = JSONDecoder()

        if let data = store.restaurantData { restaurant = (try? decoder.decode(RestaurantSettings.self, from: data)) ?? restaurant }
        if let data = store.haccpData { haccp = (try? decoder.decode(HACCPSettings.self, from: data)) ?? haccp }
        if let data = store.securityData { security = (try? decoder.decode(SecuritySettings.self, from: data)) ?? security }
        if let data = store.notificationData { notifications = (try? decoder.decode(NotificationSettings.self, from: data)) ?? notifications }
        if let data = store.printerData,
           var loaded = try? decoder.decode(LabelPrinterSettings.self, from: data) {
            loaded.applyRecommendedLayout()
            printer = loaded
        } else {
            printer.applyRecommendedLayout()
        }

        if let data = store.appearanceData,
           let decoded = try? decoder.decode(AppearanceSettings.self, from: data) {
            appearance = decoded
        }

        appearance.normalizeStoredPreferences()
        ThemeStorage.shared.mirror(appearance)
    }

    func saveAll() {
        saveDebouncer.schedule { [self] in
            persistAll()
        }
    }

    /// Salvataggio immediato (bootstrap, wipe, chiusura app).
    func saveAllImmediately() {
        saveDebouncer.cancel()
        persistAll()
    }

    private func persistAll() {
        appearance.normalizeStoredPreferences()
        ThemeStorage.shared.mirror(appearance)

        guard let store = dataStore else { return }
        let encoder = JSONEncoder()

        store.restaurantData = try? encoder.encode(restaurant)
        store.haccpData = try? encoder.encode(haccp)
        store.securityData = try? encoder.encode(security)
        store.notificationData = try? encoder.encode(notifications)
        store.printerData = try? encoder.encode(printer)
        store.appearanceData = try? encoder.encode(appearance)

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
        isHydratedFromSwiftData = false
        ThemeStorage.shared.mirror(appearance)
    }
}
