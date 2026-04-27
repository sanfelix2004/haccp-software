import SwiftData
import Foundation

@Model
public final class AppDataStore {
    public var id: String = "GLOBAL_SETTINGS"
    
    // Serialized Settings to keep it simple with SwiftData's current limitations on complex nested types
    var restaurantData: Data?
    var haccpData: Data?
    var securityData: Data?
    var notificationData: Data?
    var printerData: Data?
    
    // Multi-location management
    var activeRestaurantId: UUID?
    
    init() {
        self.id = "GLOBAL_SETTINGS"
    }
}
