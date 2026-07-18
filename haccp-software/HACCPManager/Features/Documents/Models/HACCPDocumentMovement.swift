import Foundation
import SwiftData

/// Tipo movimento permanente per i registri Documenti (mai cancellato).
enum HACCPDocumentMovementKind: String, Codable {
    case productionCompleted = "PRODUCTION_COMPLETED"
    case productionRemovedFromHistory = "PRODUCTION_REMOVED_FROM_HISTORY"
    case traceabilitySoftDeleted = "TRACEABILITY_SOFT_DELETED"
}

/// Traccia immutabile di ogni movimento operativo rilevante per ASL/Documenti.
/// Lo storico UI può nascondere voci; questo record resta sempre nei documenti.
@Model
final class HACCPDocumentMovement {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var kindRaw: String
    var occurredAt: Date
    var operatorUserId: UUID?
    var operatorName: String
    /// Es. ProduzioneBatch / TraceabilityRecord.
    var entityType: String
    var entityId: UUID
    var productionName: String?
    var lotCode: String?
    /// Riepilogo testuale ingredienti / dettaglio (persistito per PDF).
    var summary: String
    var detailJSON: String?

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        kind: HACCPDocumentMovementKind,
        occurredAt: Date = Date(),
        operatorUserId: UUID? = nil,
        operatorName: String,
        entityType: String,
        entityId: UUID,
        productionName: String? = nil,
        lotCode: String? = nil,
        summary: String,
        detailJSON: String? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.kindRaw = kind.rawValue
        self.occurredAt = occurredAt
        self.operatorUserId = operatorUserId
        self.operatorName = operatorName
        self.entityType = entityType
        self.entityId = entityId
        self.productionName = productionName
        self.lotCode = lotCode
        self.summary = summary
        self.detailJSON = detailJSON
    }

    var kind: HACCPDocumentMovementKind {
        get { HACCPDocumentMovementKind(rawValue: kindRaw) ?? .productionCompleted }
        set { kindRaw = newValue.rawValue }
    }

    var kindLabel: String {
        switch kind {
        case .productionCompleted:
            return "Produzione completata"
        case .productionRemovedFromHistory:
            return "Rimossa dallo storico operativo"
        case .traceabilitySoftDeleted:
            return "Voce nascosta dallo storico (conservata in documenti)"
        }
    }
}
