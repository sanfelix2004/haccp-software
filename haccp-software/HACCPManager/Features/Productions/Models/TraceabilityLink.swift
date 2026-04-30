import Foundation
import SwiftData

@Model
final class TraceabilityLink {
    @Attribute(.unique) var id: UUID
    var receivedItemId: UUID
    var productionId: UUID
    var quantityUsed: Double?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        receivedItemId: UUID,
        productionId: UUID,
        quantityUsed: Double? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.receivedItemId = receivedItemId
        self.productionId = productionId
        self.quantityUsed = quantityUsed
        self.createdAt = createdAt
    }
}
