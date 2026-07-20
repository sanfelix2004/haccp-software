import Foundation

/// Layout archivio: **solo report mensili**.
///
/// Struttura cartelle:
/// `{Ristorante} / Mensili / {Modulo}`
///
/// Due registri tracciabilità separati:
/// - **Tracciabilità** — produzioni, lotti, ingredienti, movimenti
/// - **Controllo scadenze** — stato operativo (disponibile / terminato / scaduto / scartato)
///
/// Politica di generazione:
/// - **Durante il mese corrente**: PDF aggiornati in modo incrementale man mano che arrivano i dati.
/// - **A fine mese** (mese chiuso): PDF finali congelati (non rigenerati se già presenti).
enum DocumentArchiveLayout {
    static let monthlyPeriodName = "Mensili"

    /// Gruppi legacy (solo migrazione da layout precedente).
    static let legacySingoliGroup = "Singoli"
    static let legacyCombinatiGroup = "Combinati"

    /// Cartella nascosta per PDF di moduli ritirati.
    static let legacyReportsArchiveFolderName = "Archivio report legacy"

    /// Ordine cartelle in archivio (una cartella per funzione).
    static let monthlyArchiveModules: [DocumentModule] = [
        .tracciabilita,
        .controlloScadenze,
        .ricezioneMerci,
        .controlloOlio,
        .decongelamento,
        .abbattimento,
        .checklist,
        .controlloPulizia,
        .frigoriferi,
        .nonConformita
    ]

    /// Moduli con registro PDF singolo.
    static let singleMonthlyModules: [DocumentModule] = [
        .tracciabilita,
        .controlloScadenze,
        .ricezioneMerci,
        .controlloOlio,
        .decongelamento,
        .abbattimento,
        .checklist,
        .controlloPulizia,
        .frigoriferi
    ]

    /// Report mensili combinati per affinità funzionale.
    static let combinedMonthlyModules: [DocumentModule] = [
        .nonConformita
    ]

    /// Cartelle legacy fuse in «Tracciabilità».
    static let retiredIntoTracciabilitaFolderTitles: Set<String> = [
        "Tracciabilità e produzioni",
        moduleFolderTitle(.etichetteProduzione),
        moduleFolderTitle(.combinatoTracciabilitaProduzione),
        "Tracciabilità status"
    ]

    /// Cartelle legacy fuse in «Controllo scadenze».
    static let retiredIntoControlloScadenzeFolderTitles: Set<String> = [
        "Controllo scadenze e quantità",
        "Controllo scadenze abbattimento"
    ]

    /// Cartelle sostituite da «Tracciabilità» o «Controllo scadenze».
    static let retiredTracciabilitaFolderTitles: Set<String> = {
        retiredIntoTracciabilitaFolderTitles.union(retiredIntoControlloScadenzeFolderTitles)
    }()

    /// Cartelle affinità precedenti (sostituite da moduli singoli).
    static let retiredAffinityFolderTitles: Set<String> = [
        moduleFolderTitle(.combinatoIngressoTracciabilita),
        moduleFolderTitle(.combinatoCatenaFreddo),
        moduleFolderTitle(.combinatoIgieneControlli),
        moduleFolderTitle(.combinatoProduzione),
        moduleFolderTitle(.haccpCombinato)
    ]

    static var retiredModuleFolderTitles: Set<String> {
        retiredTracciabilitaFolderTitles.union(retiredAffinityFolderTitles)
    }

    static func isRetiredFolderTitle(_ title: String) -> Bool {
        retiredModuleFolderTitles.contains { $0.caseInsensitiveCompare(title) == .orderedSame }
    }

    /// Moduli non più generati come PDF mensili autonomi.
    static let retiredMonthlyGenerationModules: Set<DocumentModule> = [
        .etichetteProduzione,
        .haccpCombinato,
        .combinatoIngressoTracciabilita,
        .combinatoCatenaFreddo,
        .combinatoIgieneControlli,
        .combinatoProduzione,
        .combinatoTracciabilitaProduzione
    ]

    static func isRetiredMonthlyModule(_ module: DocumentModule) -> Bool {
        retiredMonthlyGenerationModules.contains(module)
    }

    /// Remap moduli ritirati → due cartelle attive.
    static func remappedArchiveModule(for module: DocumentModule) -> DocumentModule {
        switch module {
        case .etichetteProduzione, .combinatoTracciabilitaProduzione:
            return .tracciabilita
        case .controlloScadenze:
            return .controlloScadenze
        case .tracciabilita:
            return .tracciabilita
        default:
            return module
        }
    }

    static func displayModuleLabel(for module: DocumentModule) -> String {
        remappedArchiveModule(for: module).label
    }

    static var activeMonthlyGenerationModules: [DocumentModule] {
        monthlyArchiveModules
    }

    static func isEligibleForMonthlyGeneration(type: DocumentType, module: DocumentModule) -> Bool {
        type == .mensile && activeMonthlyGenerationModules.contains(module)
    }

    static var monthEndSingleModules: [DocumentModule] { singleMonthlyModules }
    static var monthEndCombinedModules: [DocumentModule] { combinedMonthlyModules }

    static var allMonthlyModules: [DocumentModule] { monthlyArchiveModules }

    static var allMonthlyModuleFolderTitles: [String] {
        monthlyArchiveModules.map(moduleFolderTitle)
    }

    static var tracciabilitaProduzioneFolderTitle: String {
        moduleFolderTitle(.tracciabilita)
    }

    static var controlloScadenzeFolderTitle: String {
        moduleFolderTitle(.controlloScadenze)
    }

    static func venueFolderName(for restaurant: Restaurant) -> String {
        LocalDocumentStorageService.sanitizeFolderName(restaurant.name)
    }

    static func monthlyPathSuffix(for module: DocumentModule) -> String {
        moduleFolderTitle(module)
    }

    static func sourceModules(for combined: DocumentModule) -> [DocumentModule] {
        switch combined {
        case .combinatoTracciabilitaProduzione:
            return [.tracciabilita, .etichetteProduzione]
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

    static func groupFolderName(for module: DocumentModule) -> String? {
        _ = module
        return nil
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
        case .controlloScadenze: return "Controllo scadenze"
        case .checklist: return "Checklist"
        case .etichetteProduzione: return "Etichette di produzione"
        case .combinatoIngressoTracciabilita: return "Ingresso e tracciabilità"
        case .combinatoCatenaFreddo: return "Catena del freddo"
        case .combinatoIgieneControlli: return "Igiene e controlli"
        case .combinatoProduzione: return "Produzione ed etichettatura"
        case .combinatoTracciabilitaProduzione: return "Tracciabilità e produzioni"
        default: return module.label
        }
    }

    static func modules(for type: DocumentType) -> [DocumentModule] {
        switch type {
        case .mensile, .nonConformita:
            return allMonthlyModules
        default:
            return []
        }
    }

    static func remappedFlatMonthlyICloudPath(
        _ path: String,
        restaurantDisplayName: String,
        legacyGroup: String
    ) -> String? {
        let segment = "/\(monthlyPeriodName)/\(legacyGroup)/"
        guard path.contains(segment),
              let fileName = path.split(separator: "/").last.map(String.init) else { return nil }

        let parts = path.split(separator: "/").map(String.init)
        guard let monthlyIndex = parts.firstIndex(where: { $0 == monthlyPeriodName }),
              monthlyIndex + 2 < parts.count,
              parts[monthlyIndex + 1] == legacyGroup else { return nil }

        let moduleFolder = parts[monthlyIndex + 2]
        return LocalDocumentStorageService.shared.relativePathForICloud(
            restaurantDisplayName: restaurantDisplayName,
            periodFolder: monthlyPeriodName,
            groupFolder: nil,
            moduleFolder: moduleFolder,
            fileName: fileName
        )
    }

    static func remappedICloudRelativePath(
        _ path: String,
        restaurantDisplayName: String,
        oldGroup: String,
        oldModuleFolder: String,
        newGroup: String?,
        newModuleFolder: String?
    ) -> String? {
        let oldSegment = "/\(oldGroup)/\(oldModuleFolder)/"
        guard path.contains(oldSegment),
              let fileName = path.split(separator: "/").last.map(String.init) else { return nil }

        let moduleFolder = newModuleFolder ?? oldModuleFolder
        return LocalDocumentStorageService.shared.relativePathForICloud(
            restaurantDisplayName: restaurantDisplayName,
            periodFolder: monthlyPeriodName,
            groupFolder: newGroup,
            moduleFolder: moduleFolder,
            fileName: fileName
        )
    }
}
