import Foundation
import SwiftData

@Model
final class Supplier {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var name: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        name: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.name = name
        self.createdAt = createdAt
    }
}
