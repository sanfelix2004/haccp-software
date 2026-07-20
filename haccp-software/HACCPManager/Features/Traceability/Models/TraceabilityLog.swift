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
    /// Scadenza registrata nel modulo Controllo scadenze (provenienza audit).
    case expiryRegistered = "EXPIRY_REGISTERED"
    /// Lotto rimosso dalla vista operativa Controllo scadenze (consumato / terminato).
    case archivedFromExpiryControl = "ARCHIVED_EXPIRY_CONTROL"
    /// Nascosto dallo storico operativo dal MASTER (traccia resta in Documenti).
    case removedFromHistory = "REMOVED_FROM_HISTORY"
    /// Dati corretti dopo un errore di digitazione / registrazione.
    case updated = "UPDATED"
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

    /// Nome produzione collegata (da `detail` persistito o lookup catalogo).
    func linkedProductionDisplayName(productionsById: [UUID: Production]) -> String? {
        if let detail = detail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty {
            return detail
        }
        guard let productionId else { return nil }
        return productionsById[productionId]?.name
    }
}
