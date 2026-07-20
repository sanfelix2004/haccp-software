import Foundation
import SwiftData

@Model
final class TraceabilityLink {
    @Attribute(.unique) var id: UUID
    var receivedItemId: UUID
    var productionId: UUID
    /// Lotto di produzione specifico; nil = link legacy (tutte le produzioni dello stesso piatto).
    var produzioneBatchId: UUID?
    var quantityUsed: Double?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        receivedItemId: UUID,
        productionId: UUID,
        produzioneBatchId: UUID? = nil,
        quantityUsed: Double? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.receivedItemId = receivedItemId
        self.productionId = productionId
        self.produzioneBatchId = produzioneBatchId
        self.quantityUsed = quantityUsed
        self.createdAt = createdAt
    }
}
