import Foundation

enum OilAction: String, Codable, CaseIterable, Identifiable {
    case nessunaAzione = "NESSUNA_AZIONE"
    case filtrato = "FILTRATO"
    case sostituito = "SOSTITUITO"
    case smaltito = "SMALTITO"
    case puliziaFriggitrice = "PULIZIA_FRIGGITRICE"
    case altro = "ALTRO"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nessunaAzione: return "Nessuna azione"
        case .filtrato: return "Filtrato"
        case .sostituito: return "Sostituito"
        case .smaltito: return "Smaltito"
        case .puliziaFriggitrice: return "Pulizia friggitrice"
        case .altro: return "Altro"
        }
    }

    static func fromLegacy(_ value: String) -> OilAction? {
        let normalized = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        switch normalized {
        case nessunaAzione.rawValue, "nessuna azione", "nessunaazione":
            return .nessunaAzione
        case filtrato.rawValue, "filtrato":
            return .filtrato
        case sostituito.rawValue, "sostituito":
            return .sostituito
        case smaltito.rawValue, "smaltito":
            return .smaltito
        case puliziaFriggitrice.rawValue, "pulizia friggitrice", "puliziafriggitrice":
            return .puliziaFriggitrice
        case altro.rawValue, "altro":
            return .altro
        default:
            return nil
        }
    }
}
