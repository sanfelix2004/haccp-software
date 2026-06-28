import Foundation

enum ProduzioneBatchStatus: String, Codable, CaseIterable {
    case inCorso = "IN_CORSO"
    case completato = "COMPLETATO"
    case annullato = "ANNULLATO"

    var label: String {
        switch self {
        case .inCorso: return "In corso"
        case .completato: return "Completato"
        case .annullato: return "Annullato"
        }
    }
}

enum IngredienteTracciatoStato: String, Codable, CaseIterable {
    case ocrInAttesa = "OCR_IN_ATTESA"
    /// Foto + lotto salvati e legati alla produzione (automatico).
    case lottoRegistrato = "LOTTO_REGISTRATO"
    /// Foto salvata; lotto da inserire manualmente.
    case richiedeLotto = "RICHIEDE_LOTTO"
    /// Lotto legato; materia prima da selezionare.
    case richiedeMateriaPrima = "RICHIEDE_MATERIA_PRIMA"
    /// Lotto + materia prima: traccia completa.
    case completo = "COMPLETO"
    // Legacy — mappati in lettura per dati esistenti
    case ocrCompletato = "OCR_COMPLETATO"
    case ocrFallito = "OCR_FALLITO"
    case nonRiconosciuto = "NON_RICONOSCIUTO"
    case ingredienteAssegnato = "INGREDIENTE_ASSEGNATO"
    case confermatoOperatore = "CONFERMATO_OPERATORE"

    var label: String {
        switch self {
        case .ocrInAttesa: return "Analisi…"
        case .lottoRegistrato: return "Assegna alimento"
        case .richiedeLotto: return "Inserisci lotto"
        case .richiedeMateriaPrima: return "Seleziona materia prima"
        case .completo, .confermatoOperatore: return "Completo"
        case .ocrCompletato: return "Lettura AI completata"
        case .ocrFallito: return "Lettura AI fallita"
        case .nonRiconosciuto: return "Seleziona materia prima"
        case .ingredienteAssegnato: return "Materia prima assegnata"
        }
    }

    var needsIngredientPick: Bool {
        switch self {
        case .richiedeMateriaPrima, .nonRiconosciuto, .lottoRegistrato, .ingredienteAssegnato:
            return true
        default:
            return false
        }
    }

    var needsLotEntry: Bool {
        switch self {
        case .richiedeLotto, .ocrFallito:
            return true
        default:
            return false
        }
    }

    var isTraceComplete: Bool {
        self == .completo || self == .confermatoOperatore
    }
}
