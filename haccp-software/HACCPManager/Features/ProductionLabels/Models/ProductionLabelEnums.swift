//
//  ProductionLabelEnums.swift
//  Etichette HACCP — tipi e stati.
//

import Foundation

enum ProductionLabelSource: String, Codable, CaseIterable {
    case manual = "MANUAL"
    case traceability = "TRACEABILITY"
    case goodsReceiving = "GOODS_RECEIVING"
    case blastChilling = "BLAST_CHILLING"
    case defrost = "DEFROST"
    case production = "PRODUCTION"

    var label: String {
        switch self {
        case .manual: return "Manuale"
        case .traceability: return "Tracciabilità"
        case .goodsReceiving: return "Ricezione merci"
        case .blastChilling: return "Abbattimento"
        case .defrost: return "Decongelamento"
        case .production: return "Produzione"
        }
    }

    /// Nome mostrato in UI: le etichette legacy da ricezione rientrano in tracciabilità;
    /// quelle dal catalogo piatti rientrano in abbattimento.
    var displayLabel: String {
        switch self {
        case .goodsReceiving: return Self.traceability.label
        case .production: return Self.blastChilling.label
        default: return label
        }
    }

    /// Titolo breve per le schede del modulo etichette.
    var tabTitle: String {
        switch self {
        case .manual: return "Manuale"
        case .traceability: return "Tracciabilità"
        case .goodsReceiving: return "Ricezione"
        case .blastChilling: return "Abbattimento"
        case .defrost: return "Decongelamento"
        case .production: return "Produzione"
        }
    }

    var icon: String {
        switch self {
        case .manual: return "tag.fill"
        case .traceability: return "archivebox.fill"
        case .goodsReceiving: return "shippingbox.fill"
        case .blastChilling: return "wind.snow"
        case .defrost: return "snowflake"
        case .production: return "fork.knife"
        }
    }
}

/// Moduli HACCP collegabili alle etichette (escluso manuale).
/// Ricezione merci non è una scheda separata: ogni ricezione crea un lotto in tracciabilità.
/// Il catalogo piatti non genera etichette: si etichetta il lotto preparato da Abbattimento.
enum ProductionLabelLinkedSource: String, CaseIterable, Identifiable, Hashable {
    case traceability
    case blastChilling
    case defrost

    var id: String { rawValue }

    var labelSource: ProductionLabelSource {
        switch self {
        case .traceability: return .traceability
        case .blastChilling: return .blastChilling
        case .defrost: return .defrost
        }
    }

    var title: String {
        switch self {
        case .traceability: return "Produzione finita"
        case .blastChilling, .defrost: return labelSource.tabTitle
        }
    }

    var icon: String {
        switch self {
        case .traceability: return "fork.knife"
        default: return labelSource.icon
        }
    }

    var subtitle: String {
        switch self {
        case .traceability: return "Piatti preparati dopo associazione lotti"
        case .blastChilling: return "Abbattimenti completati"
        case .defrost: return "Decongelamenti completati"
        }
    }

    var emptyItemsMessage: String {
        switch self {
        case .traceability: return "Non ci sono produzioni da etichettare. Completa una Tracciabilità (foto → Alimento Produzione → salva)."
        case .blastChilling: return "Non ci sono abbattimenti completati."
        case .defrost: return "Non ci sono decongelamenti completati."
        }
    }

    init?(labelSource: ProductionLabelSource) {
        switch labelSource {
        case .traceability, .goodsReceiving: self = .traceability
        case .blastChilling, .production: self = .blastChilling
        case .defrost: self = .defrost
        case .manual: return nil
        }
    }
}

enum ProductionLabelStatus: String, Codable, CaseIterable {
    case draft = "DRAFT"
    case active = "ACTIVE"
    case reprinted = "REPRINTED"
    case voided = "VOIDED"

    var label: String {
        switch self {
        case .draft: return "Bozza"
        case .active: return "Attiva"
        case .reprinted: return "Ristampa"
        case .voided: return "Annullata"
        }
    }
}

enum ProductionLabelProductStatus: String, Codable, CaseIterable {
    case ready = "READY"
    case inUse = "IN_USE"
    case blastChilled = "BLAST_CHILLED"
    case defrosted = "DEFROSTED"
    case consumed = "CONSUMED"

    var label: String {
        switch self {
        case .ready: return "Pronto"
        case .inUse: return "In uso"
        case .blastChilled: return "Abbattuto"
        case .defrosted: return "Decongelato"
        case .consumed: return "Consumato"
        }
    }
}

enum ProductionLabelExpiryState {
    case ok
    case soon
    case expired

    var badgeTitle: String {
        switch self {
        case .ok: return "In scadenza OK"
        case .soon: return "Scade presto"
        case .expired: return "Scaduto"
        }
    }
}

/// Stato scadenza di un elemento HACCP in attesa di etichetta.
enum ProductionLabelSourceItemExpiry: Equatable {
    case rejected
    case expired
    case soon
    case ok
    case unknown

    var badgeTitle: String {
        switch self {
        case .rejected: return "Respinto"
        case .expired: return "Scaduto"
        case .soon: return "In scadenza"
        case .ok: return "Valido"
        case .unknown: return "Scadenza N/D"
        }
    }

    var badgeStyle: HACCPBadgeStyle {
        switch self {
        case .rejected, .expired: return .nonConforme
        case .soon: return .warning
        case .ok: return .conforme
        case .unknown: return .neutral
        }
    }

    var sortOrder: Int {
        switch self {
        case .expired: return 0
        case .rejected: return 1
        case .soon: return 2
        case .ok: return 3
        case .unknown: return 4
        }
    }
}
