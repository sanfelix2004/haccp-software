import Foundation
import SwiftData

@Model
final class OilPoint {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var name: String
    var isActive: Bool
    var createdAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        name: String,
        isActive: Bool = true,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.name = name
        self.isActive = isActive
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
    }
}
