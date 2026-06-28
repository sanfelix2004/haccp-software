import Foundation
import SwiftData

/// Alimento in ingresso associato a una produzione (ricetta tracciabilità) con durata conservazione.
@Model
final class ProductionIncomingIngredient {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var productionId: UUID
    var productTemplateId: UUID
    var productNameSnapshot: String
    /// Giorni di durata/conservazione (scadenza interna suggerita per il prodotto finito).
    var durationDays: Int
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        productionId: UUID,
        productTemplateId: UUID,
        productNameSnapshot: String,
        durationDays: Int = 3,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.productionId = productionId
        self.productTemplateId = productTemplateId
        self.productNameSnapshot = productNameSnapshot
        self.durationDays = max(1, durationDays)
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
