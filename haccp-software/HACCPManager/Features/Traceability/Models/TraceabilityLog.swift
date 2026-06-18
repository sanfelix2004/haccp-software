import Foundation
import SwiftData

enum TraceabilityActionType: String, Codable {
    case created = "CREATED"
    case linkedToProduction = "LINKED_TO_PRODUCTION"
    case expired = "EXPIRED"
    case rejected = "REJECTED"
    /// Non conformità segnalata con motivo, azione correttiva e foto obbligatoria.
    case nonCompliance = "NON_COMPLIANCE"
    /// Lotto scaduto ritirato o scartato dall'operatore.
    case withdrawn = "WITHDRAWN"
}

@Model
final class TraceabilityLog {
    @Attribute(.unique) var id: UUID
    var receivedItemId: UUID
    var productionId: UUID?
    var actionTypeRaw: String
    var timestamp: Date
    var operatorName: String
    /// Dettaglio audit (es. tipo ritiro/scarto e note sintetiche).
    var detail: String?

    init(
        id: UUID = UUID(),
        receivedItemId: UUID,
        productionId: UUID? = nil,
        actionType: TraceabilityActionType,
        timestamp: Date = Date(),
        operatorName: String,
        detail: String? = nil
    ) {
        self.id = id
        self.receivedItemId = receivedItemId
        self.productionId = productionId
        self.actionTypeRaw = actionType.rawValue
        self.timestamp = timestamp
        self.operatorName = operatorName
        self.detail = detail
    }

    var actionType: TraceabilityActionType {
        get { TraceabilityActionType(rawValue: actionTypeRaw) ?? .created }
        set { actionTypeRaw = newValue.rawValue }
    }
}
