import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case profile = "Profilo Utente"
    case appearance = "Aspetto"
    case security = "Sicurezza"
    case restaurant = "Ristorante"
    case haccp = "Parametri HACCP"
    case notifications = "Notifiche"
    case data = "Dati e Backup"
    case printer = "Stampanti"
    case info = "Info App"

    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .profile: return "person.crop.circle.fill"
        case .appearance: return "paintpalette.fill"
        case .security: return "shield.lefthalf.filled"
        case .restaurant: return "house.fill"
        case .haccp: return "thermometer.medium"
        case .notifications: return "bell.fill"
        case .data: return "externaldrive.fill"
        case .printer: return "printer.fill"
        case .info: return "info.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .profile: return "Nome, PIN e iCloud."
        case .appearance: return "Tema e modalità cucina."
        case .security: return "PIN, biometria e blocco."
        case .restaurant: return "Dati locale e logo."
        case .haccp: return "Temperature e soglie."
        case .notifications: return "Avvisi e promemoria."
        case .data: return "Spazio e backup."
        case .printer: return "Etichette Bluetooth."
        case .info: return "Versione e documenti legali."
        }
    }

    /// Sezioni accessibili all'operatore HACCP senza PIN MASTER.
    var isOperatorAccessible: Bool {
        switch self {
        case .profile, .appearance, .notifications, .info:
            return true
        default:
            return false
        }
    }
}
