import Foundation
import SwiftData

/// Relazione molti-a-molti: `LottoFoto` ↔ `Production`.
@Model
final class LottoFotoProductionLink {
    @Attribute(.unique) var id: UUID
    var lottoFotoId: UUID
    var productionId: UUID
    var produzioneBatchId: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        lottoFotoId: UUID,
        productionId: UUID,
        produzioneBatchId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.lottoFotoId = lottoFotoId
        self.productionId = productionId
        self.produzioneBatchId = produzioneBatchId
        self.createdAt = createdAt
    }
}
