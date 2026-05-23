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
