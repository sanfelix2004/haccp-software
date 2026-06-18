import Foundation

/// Layout archivio: **solo report mensili**.
///
/// Struttura cartelle:
/// `{Ristorante} / Mensili / Singoli|Combinati / {Modulo}`
///
/// Politica di generazione:
/// - **Durante il mese corrente**: nessuna generazione automatica.
/// - **A fine mese** (mese chiuso): PDF per ogni funzione + report combinati per affinità + NC.
enum DocumentArchiveLayout {
    static let monthlyPeriodName = "Mensili"
    static let singoliGroup = "Singoli"
    static let combinatiGroup = "Combinati"

    /// Un report mensile per ogni modulo operativo (cartella in Singoli).
    static let singleMonthlyModules: [DocumentModule] = [
        .ricezioneMerci,
        .tracciabilita,
        .frigoriferi,
        .controlloPulizia,
        .abbattimento,
        .decongelamento,
        .controlloOlio,
        .checklist,
        .etichetteProduzione
    ]

    /// Report combinati mensili (cartella in Combinati) — funzioni affini + sintesi generale.
    static let combinedMonthlyModules: [DocumentModule] = [
        .combinatoIngressoTracciabilita,
        .combinatoCatenaFreddo,
        .combinatoIgieneControlli,
        .combinatoProduzione,
        .haccpCombinato,
        .nonConformita
    ]

    static var monthEndSingleModules: [DocumentModule] { singleMonthlyModules }
    static var monthEndCombinedModules: [DocumentModule] { combinedMonthlyModules }

    static let singleModuleFolderTitles: [String] = [
        "Ricezione merci",
        "Tracciabilità",
        "Frigoriferi",
        "Controllo pulizia",
        "Abbattimento",
        "Decongelamento",
        "Controllo olio",
        "Checklist",
        "Etichette di produzione"
    ]

    static let combinedModuleFolderTitles: [String] = [
        "Ingresso e tracciabilità",
        "Catena del freddo",
        "Igiene e controlli",
        "Produzione ed etichettatura",
        "HACCP combinato",
        "Non conformità"
    ]

    static func venueFolderName(for restaurant: Restaurant) -> String {
        LocalDocumentStorageService.sanitizeFolderName(restaurant.name)
    }

    /// Moduli sorgente inclusi in un report combinato per affinità.
    static func sourceModules(for combined: DocumentModule) -> [DocumentModule] {
        switch combined {
        case .combinatoIngressoTracciabilita:
            return [.ricezioneMerci, .tracciabilita]
        case .combinatoCatenaFreddo:
            return [.frigoriferi, .abbattimento, .decongelamento]
        case .combinatoIgieneControlli:
            return [.controlloPulizia, .checklist]
        case .combinatoProduzione:
            return [.etichetteProduzione, .controlloOlio]
        default:
            return []
        }
    }

    static func isAffinityCombined(_ module: DocumentModule) -> Bool {
        !sourceModules(for: module).isEmpty
    }

    static func isSingleModule(_ module: DocumentModule) -> Bool {
        singleMonthlyModules.contains(module)
    }

    static func isOperationalSingle(_ module: DocumentModule) -> Bool {
        switch module {
        case .frigoriferi, .controlloPulizia, .abbattimento, .decongelamento,
             .controlloOlio, .checklist, .etichetteProduzione:
            return true
        default:
            return false
        }
    }

    static func groupFolderName(for module: DocumentModule) -> String {
        if module == .nonConformita || module.isCombinedArchive {
            return combinatiGroup
        }
        return singoliGroup
    }

    static func moduleFolderTitle(_ module: DocumentModule) -> String {
        switch module {
        case .ricezioneMerci: return "Ricezione merci"
        case .tracciabilita: return "Tracciabilità"
        case .haccpCombinato: return "HACCP combinato"
        case .nonConformita: return "Non conformità"
        case .frigoriferi: return "Frigoriferi"
        case .controlloPulizia: return "Controllo pulizia"
        case .abbattimento: return "Abbattimento"
        case .decongelamento: return "Decongelamento"
        case .controlloOlio: return "Controllo olio"
        case .checklist: return "Checklist"
        case .etichetteProduzione: return "Etichette di produzione"
        case .combinatoIngressoTracciabilita: return "Ingresso e tracciabilità"
        case .combinatoCatenaFreddo: return "Catena del freddo"
        case .combinatoIgieneControlli: return "Igiene e controlli"
        case .combinatoProduzione: return "Produzione ed etichettatura"
        default: return module.label
        }
    }

    static func modules(for type: DocumentType) -> [DocumentModule] {
        switch type {
        case .mensile, .nonConformita:
            return singleMonthlyModules + combinedMonthlyModules
        default:
            return []
        }
    }
}
