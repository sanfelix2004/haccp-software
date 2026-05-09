import Foundation

enum HistoryModule: String, CaseIterable, Identifiable {
    case goodsReceiving = "Ricezione merci"
    case traceability = "Tracciabilità"
    case fridges = "Frigoriferi"
    case cleaningControl = "Controllo pulizia"
    case blastChilling = "Abbattimento"
    case scheduling = "Programmazione"
    case expiryControl = "Controllo scadenze"
    case defrost = "Decongelamento"
    case oilControl = "Controllo olio"
    case productionLabels = "Etichette di produzione"
    case moduleTimer = "Module Timer"
    case checklist = "Checklist"

    var id: String { rawValue }

    static let dashboardModules: [HistoryModule] = [
        .goodsReceiving,
        .traceability,
        .fridges,
        .cleaningControl,
        .blastChilling,
        .scheduling,
        .expiryControl,
        .defrost,
        .oilControl,
        .productionLabels,
        .moduleTimer
    ]

    var icon: String {
        switch self {
        case .goodsReceiving: return "shippingbox.fill"
        case .traceability: return "archivebox.fill"
        case .fridges: return "thermometer.medium"
        case .cleaningControl: return "sparkles"
        case .blastChilling: return "wind.snow"
        case .scheduling: return "calendar.badge.clock"
        case .expiryControl: return "calendar.badge.exclamationmark"
        case .defrost: return "snowflake"
        case .oilControl: return "drop.fill"
        case .productionLabels: return "tag.fill"
        case .moduleTimer: return "timer"
        case .checklist: return "checklist"
        }
    }
}
