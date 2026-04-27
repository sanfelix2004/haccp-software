import Foundation

public struct RestaurantSettings: Codable {
    var name: String = ""
    var legalName: String = ""
    var address: String = ""
    var city: String = ""
    var vatNumber: String = ""
    var haccpManager: String = ""
    var phone: String = ""
    var email: String = ""
    var openingHours: String = ""
    var notes: String = ""
    var logoData: Data? = nil
    
    var isConfigured: Bool {
        !name.isEmpty && !address.isEmpty
    }
}
