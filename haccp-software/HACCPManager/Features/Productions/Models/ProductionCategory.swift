import Foundation
import SwiftData

@Model
final class ProductionCategory {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var name: String
    var orderIndex: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        name: String,
        orderIndex: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.name = name
        self.orderIndex = orderIndex
        self.createdAt = createdAt
    }
}
