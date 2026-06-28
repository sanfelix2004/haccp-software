import Foundation

/// Esito della ricezione merci (solo ingresso fisico, no lotti).
enum RicezioneMerceEsito: String, Codable, CaseIterable {
    case conforme = "CONFORME"
    case nonConforme = "NON_CONFORME"

    var label: String {
        switch self {
        case .conforme: return "Conforme"
        case .nonConforme: return "Non conforme"
        }
    }
}

/// Azione intrapresa su merce anomala.
enum AzioneNonConformita: String, Codable, CaseIterable, Identifiable {
    case scartata = "SCARTATA"
    case mandataIndietro = "MANDATA_INDIETRO_AL_FORNITORE"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .scartata: return "Scartata"
        case .mandataIndietro: return "Mandata indietro al fornitore"
        }
    }
}

/// Alias semantico: la ricezione merci resta persistita come `GoodsReceivingRecord` (compatibilità SwiftData).
typealias RicezioneMerce = GoodsReceivingRecord
