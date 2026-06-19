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

    /// Cartella nascosta per PDF di moduli ritirati (es. HACCP combinato).
    static let legacyReportsArchiveFolderName = "Archivio report legacy"

    /// Moduli/cartelle non più esposti in archivio (sostituiti da «Ingresso e tracciabilità»).
    static let retiredSingoliFolderTitles: Set<String> = [
        moduleFolderTitle(.ricezioneMerci),
        moduleFolderTitle(.tracciabilita)
    ]
    static let retiredCombinatiFolderTitles: Set<String> = [
        moduleFolderTitle(.haccpCombinato)
    ]
    static var retiredModuleFolderTitles: Set<String> {
        retiredSingoliFolderTitles.union(retiredCombinatiFolderTitles)
    }

    static func isRetiredFolderTitle(_ title: String) -> Bool {
        retiredModuleFolderTitles.contains { $0.caseInsensitiveCompare(title) == .orderedSame }
    }

    /// Moduli non più generati come PDF singoli/combinato generale mensile.
    static let retiredMonthlyGenerationModules: Set<DocumentModule> = [
        .ricezioneMerci,
        .tracciabilita,
        .haccpCombinato
    ]

    static func isRetiredMonthlyModule(_ module: DocumentModule) -> Bool {
        retiredMonthlyGenerationModules.contains(module)
    }

    /// Moduli ammessi nella generazione automatica mensile.
    static var activeMonthlyGenerationModules: [DocumentModule] {
        monthEndSingleModules + monthEndCombinedModules
    }

    static func isEligibleForMonthlyGeneration(type: DocumentType, module: DocumentModule) -> Bool {
        type == .mensile && activeMonthlyGenerationModules.contains(module)
    }

    /// Un report mensile per ogni modulo operativo (cartella in Singoli).
    static let singleMonthlyModules: [DocumentModule] = [
        .frigoriferi,
        .controlloPulizia,
        .abbattimento,
        .decongelamento,
        .controlloOlio,
        .checklist,
        .etichetteProduzione
    ]

    /// Report combinati mensili (cartella in Combinati) — funzioni affini + registro NC.
    static let combinedMonthlyModules: [DocumentModule] = [
        .combinatoIngressoTracciabilita,
        .combinatoCatenaFreddo,
        .combinatoIgieneControlli,
        .combinatoProduzione,
        .nonConformita
    ]

    static var monthEndSingleModules: [DocumentModule] { singleMonthlyModules }
    static var monthEndCombinedModules: [DocumentModule] { combinedMonthlyModules }

    /// Titoli cartella derivati dai moduli attivi — unica fonte di verità con le liste sopra.
    static var singleModuleFolderTitles: [String] {
        singleMonthlyModules.map(moduleFolderTitle)
    }

    static var combinedModuleFolderTitles: [String] {
        combinedMonthlyModules.map(moduleFolderTitle)
    }

    static var ingressoTracciabilitaFolderTitle: String {
        moduleFolderTitle(.combinatoIngressoTracciabilita)
    }

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
        isSingleModule(module)
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

    /// Ricostruisce il path iCloud dopo migrazione cartella (evita replace string fragile).
    static func remappedICloudRelativePath(
        _ path: String,
        restaurantDisplayName: String,
        oldGroup: String,
        oldModuleFolder: String,
        newGroup: String,
        newModuleFolder: String?
    ) -> String? {
        let oldSegment = "/\(oldGroup)/\(oldModuleFolder)/"
        guard path.contains(oldSegment),
              let fileName = path.split(separator: "/").last.map(String.init) else { return nil }

        let prefix = "HACCP Manager/\(venueFolderName(fromDisplayName: restaurantDisplayName))/\(monthlyPeriodName)"
        let moduleFolder = newModuleFolder ?? ""
        if moduleFolder.isEmpty {
            return "\(prefix)/\(newGroup)/\(fileName)"
        }
        return LocalDocumentStorageService.shared.relativePathForICloud(
            restaurantDisplayName: restaurantDisplayName,
            periodFolder: monthlyPeriodName,
            groupFolder: newGroup,
            moduleFolder: moduleFolder,
            fileName: fileName
        )
    }

    private static func venueFolderName(fromDisplayName name: String) -> String {
        LocalDocumentStorageService.sanitizeFolderName(name)
    }
}
