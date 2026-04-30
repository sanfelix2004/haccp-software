import Foundation
import SwiftData

@Model
final class Production {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var name: String
    var categoryId: UUID
    var categoryNameSnapshot: String
    var createdAt: Date
    var isCustom: Bool

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        name: String,
        categoryId: UUID,
        categoryNameSnapshot: String,
        createdAt: Date = Date(),
        isCustom: Bool
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.name = name
        self.categoryId = categoryId
        self.categoryNameSnapshot = categoryNameSnapshot
        self.createdAt = createdAt
        self.isCustom = isCustom
    }
}
