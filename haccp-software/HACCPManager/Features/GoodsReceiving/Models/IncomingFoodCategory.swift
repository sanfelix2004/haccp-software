import Foundation
import SwiftData

/// Categoria utente per alimenti in ingresso (oltre alle categorie HACCP di default).
@Model
final class IncomingFoodCategory {
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
