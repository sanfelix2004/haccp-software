import Foundation

enum OilStatus: String, Codable, CaseIterable, Identifiable {
    case conforme = "CONFORME"
    case daMonitorare = "DA_MONITORARE"
    case daSostituire = "DA_SOSTITUIRE"
    case nonConforme = "NON_CONFORME"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .conforme: return "Conforme"
        case .daMonitorare: return "Da monitorare"
        case .daSostituire: return "Da sostituire"
        case .nonConforme: return "Non conforme"
        }
    }

    static func fromLegacy(_ value: String) -> OilStatus? {
        let normalized = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        switch normalized {
        case conforme.rawValue, "conforme":
            return .conforme
        case daMonitorare.rawValue, "da monitorare", "damonitorare":
            return .daMonitorare
        case daSostituire.rawValue, "da sostituire", "dasostituire":
            return .daSostituire
        case nonConforme.rawValue, "non conforme", "nonconforme":
            return .nonConforme
        default:
            return nil
        }
    }

    var isCritical: Bool {
        self == .daSostituire || self == .nonConforme
    }
}
