import Foundation
import SwiftData

@Model
public final class Restaurant {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var address: String
    public var city: String
    public var haccpManager: String
    public var phone: String
    public var email: String
    public var notes: String
    public var restaurantPinHash: String = ""
    public var logoData: Data?
    public var creationDate: Date
    
    public init(id: UUID = UUID(),
         name: String,
         address: String = "",
         city: String = "",
         haccpManager: String = "",
         phone: String = "",
         email: String = "",
         notes: String = "",
         restaurantPinHash: String = "",
         logoData: Data? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.city = city
        self.haccpManager = haccpManager
        self.phone = phone
        self.email = email
        self.notes = notes
        self.restaurantPinHash = restaurantPinHash
        self.logoData = logoData
        self.creationDate = Date()
    }
}
