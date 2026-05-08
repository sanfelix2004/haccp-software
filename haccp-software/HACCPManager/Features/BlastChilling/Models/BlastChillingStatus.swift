import Foundation

enum BlastChillingStatus: String, Codable, CaseIterable, Identifiable {
    case conforme = "CONFORME"
    case nonConforme = "NON_CONFORME"
    case inCorso = "IN_CORSO"
    case annullato = "ANNULLATO"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .conforme: return "Conforme"
        case .nonConforme: return "Non conforme"
        case .inCorso: return "In corso"
        case .annullato: return "Annullato"
        }
    }
}
