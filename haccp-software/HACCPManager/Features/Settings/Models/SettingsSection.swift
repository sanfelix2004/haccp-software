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
        case .profile: return "Gestisci i tuoi dati e il tuo PIN."
        case .appearance: return "Temi premium, layout e modalità cucina."
        case .security: return "Protezione app e biometria."
        case .restaurant: return "Dati del locale e logo aziendale."
        case .haccp: return "Range temperature e soglie critiche."
        case .notifications: return "Avvisi e promemoria checklist."
        case .data: return "Uso memoria e reset sistema."
        case .printer: return "Configura stampanti per etichette."
        case .info: return "Versioni e note legali."
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
