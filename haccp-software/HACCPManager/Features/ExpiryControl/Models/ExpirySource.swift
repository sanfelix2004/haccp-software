import Foundation

/// Provenienza della data di scadenza — audit HACCP.
enum ExpirySource: String, Codable, Sendable {
    case groqLabel = "GROQ_ETICHETTA"
    case shelfLifeCatalog = "SHELF_LIFE_CATALOGO"
    case manualOperator = "MANUALE_OPERATORE"
    case productionShelfLife = "SHELF_LIFE_PRODUZIONE"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case Self.groqLabel.rawValue, "OCA_ETICHETTA":
            self = .groqLabel
        case Self.shelfLifeCatalog.rawValue:
            self = .shelfLifeCatalog
        case Self.manualOperator.rawValue:
            self = .manualOperator
        case Self.productionShelfLife.rawValue:
            self = .productionShelfLife
        default:
            self = .manualOperator
        }
    }

    var auditLabel: String {
        switch self {
        case .groqLabel: return "Estratta da etichetta (Groq AI)"
        case .shelfLifeCatalog: return "Calcolata da shelf-life"
        case .manualOperator: return "Inserita manualmente dall'operatore"
        case .productionShelfLife: return "Calcolata da shelf-life produzione"
        }
    }

    var shortLabel: String {
        switch self {
        case .groqLabel: return "Da etichetta (AI)"
        case .shelfLifeCatalog: return "Da catalogo"
        case .manualOperator: return "Manuale"
        case .productionShelfLife: return "Produzione"
        }
    }
}

enum ExpiryTrackingError: LocalizedError {
    case expiredProductRequiresAcknowledgment

    var errorDescription: String? {
        switch self {
        case .expiredProductRequiresAcknowledgment:
            return "ATTENZIONE: La data di scadenza letta indica che il prodotto è già SCADUTO. Verificare l'etichetta."
        }
    }
}
