import Foundation
import SwiftData

/// Istanza operativa di una produzione (es. Crema Pasticcera Batch #01).
@Model
final class ProduzioneBatch {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var productionId: UUID
    var productionNameSnapshot: String
    var batchCode: String
    var producedAt: Date
    var internalExpiryAt: Date?
    var statusRaw: String
    var notes: String?
    var createdAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var isArchived: Bool
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        productionId: UUID,
        productionNameSnapshot: String,
        batchCode: String,
        producedAt: Date = Date(),
        internalExpiryAt: Date? = nil,
        status: ProduzioneBatchStatus = .inCorso,
        notes: String? = nil,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        isArchived: Bool = false,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.productionId = productionId
        self.productionNameSnapshot = productionNameSnapshot
        self.batchCode = batchCode
        self.producedAt = producedAt
        self.internalExpiryAt = internalExpiryAt
        self.statusRaw = status.rawValue
        self.notes = notes
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.isArchived = isArchived
        self.archivedAt = archivedAt
    }

    var status: ProduzioneBatchStatus {
        get { ProduzioneBatchStatus(rawValue: statusRaw) ?? .inCorso }
        set { statusRaw = newValue.rawValue }
    }
}
