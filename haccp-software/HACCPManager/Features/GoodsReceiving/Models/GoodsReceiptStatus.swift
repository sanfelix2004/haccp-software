import Foundation

enum GoodsReceiptStatus: String, Codable, CaseIterable {
    case conforme = "CONFORME"
    case nonConforme = "NON_CONFORME"
    case acceptedWithNotes = "ACCETTATO_CON_NOTE"
    case rejected = "RIFIUTATO"

    var label: String {
        switch self {
        case .conforme: return "Conforme"
        case .nonConforme: return "Non conforme"
        case .acceptedWithNotes: return "Accettato con note"
        case .rejected: return "Rifiutato"
        }
    }
}
