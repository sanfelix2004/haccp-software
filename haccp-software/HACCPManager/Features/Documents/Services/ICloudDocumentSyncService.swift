import Combine
import Foundation
import SwiftData

// Attivazione firma iCloud (una tantum): Apple Developer → App ID `com.haccpmanager.app` →
// iCloud → iCloud Documents → container `iCloud.com.haccpmanager.app`. In Xcode → target
// HACCP Manager → Signing & Capabilities → + iCloud → iCloud Documents → stesso container,
// oppure imposta `CODE_SIGN_ENTITLEMENTS` su `haccp-software/HACCP Manager.entitlements`.
// Senza provisioning iCloud, `isUbiquityContainerAvailable` è false: l’app funziona solo offline.

/// Sincronizza **solo file PDF** nel container iCloud Drive (ubiquity). SwiftData resta sempre locale.
/// Se iCloud non è disponibile o l’utente non ha attivato l’opzione, tutto continua a funzionare offline.
@MainActor
final class ICloudDocumentSyncService: ObservableObject, ICloudDocumentSyncServiceProtocol {
    static let shared = ICloudDocumentSyncService()

    /// Deve coincidere con `com.apple.developer.icloud-container-identifiers` negli entitlement e con il container creato in Apple Developer.
    private static let ubiquityContainerIdentifier = "iCloud.com.haccpmanager.app"

    private let fileManager = FileManager.default
    private var ubiquityObserver: NSObjectProtocol?

    /// Messaggio umano: perché iCloud è ok oppure cosa manca (per la schermata Impostazioni).
    @Published private(set) var connectionExplanation: String = ""

    /// Ultima operazione di copia PDF (successo / errore / skip).
    @Published private(set) var lastSyncActivity: String = ""

    @Published private(set) var lastSyncActivityDate: Date?

    private init() {
        publishConnectionDiagnostics()
        ubiquityObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSUbiquityIdentityDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.publishConnectionDiagnostics()
                self?.lastSyncActivity = "Account iCloud cambiato sul dispositivo — stato aggiornato."
                self?.lastSyncActivityDate = Date()
            }
        }
    }

    func refreshConnectionDiagnostics() {
        publishConnectionDiagnostics()
    }

    /// Il container può essere `nil` al primo avvio anche con entitlements corretti: ritenta con breve attesa.
    func resolveUbiquityContainerURL(maxAttempts: Int = 6) async -> URL? {
        for attempt in 0..<maxAttempts {
            if let url = fileManager.url(forUbiquityContainerIdentifier: Self.ubiquityContainerIdentifier) {
                publishConnectionDiagnostics()
                return url
            }
            if attempt < maxAttempts - 1 {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        publishConnectionDiagnostics()
        return nil
    }

    private func publishConnectionDiagnostics() {
        let hasIdentity = fileManager.ubiquityIdentityToken != nil
        let containerURL = fileManager.url(forUbiquityContainerIdentifier: Self.ubiquityContainerIdentifier)

        if let url = containerURL {
            let path = url.path
            connectionExplanation =
                "Collegato a iCloud: il container dell’app è attivo.\nPercorso tecnico: \(path)\n\n" +
                "Quando la sincronizzazione è attiva, i PDF vengono copiati qui sotto «Documents». " +
                "In app File puoi cercare la cartella dell’app in iCloud Drive."
        } else if !hasIdentity {
            connectionExplanation =
                "Non collegato: su questo dispositivo non risulta un account iCloud attivo, " +
                "oppure iCloud Drive è disattivato.\n\n" +
                "Vai in Impostazioni → [il tuo nome] → iCloud → iCloud Drive e assicurati che sia acceso, poi premi Verifica."
        } else {
            connectionExplanation =
                "Account iCloud rilevato sul dispositivo, ma questa build non può usare iCloud Drive.\n\n" +
                "• Con team di sviluppo personale (gratuito) Apple non consente la capability iCloud\n" +
                "• Per la sync documenti serve l’Apple Developer Program (account a pagamento)\n" +
                "• L’app continua a funzionare: PDF e registri restano salvati sul dispositivo\n\n" +
                "Dopo l’iscrizione al programma developer, compila in Release con il team a pagamento " +
                "e reinstalla l’app sul dispositivo."
        }
    }

    private func recordSyncActivity(_ message: String) {
        lastSyncActivity = message
        lastSyncActivityDate = Date()
    }

    // MARK: - ICloudDocumentSyncServiceProtocol

    var isUbiquityContainerAvailable: Bool {
        fileManager.url(forUbiquityContainerIdentifier: Self.ubiquityContainerIdentifier) != nil
    }

    var isUserPDFSyncEnabled: Bool {
        get { DocumentsUserSettings.isICloudPDFSyncEnabled }
        set { DocumentsUserSettings.isICloudPDFSyncEnabled = newValue }
    }

    /// Copia il PDF nel container iCloud sotto `Documents/<iCloudRelativePath>`.
    func syncDocument(_ item: DocumentItem, modelContext: ModelContext) async {
        guard DocumentsUserSettings.isICloudPDFSyncEnabled else {
            return
        }
        guard isUbiquityContainerAvailable else {
            return
        }
        guard item.format == .pdf, item.localFilePresent else {
            return
        }
        let localURL = URL(fileURLWithPath: item.filePath)
        guard fileManager.fileExists(atPath: localURL.path) else {
            return
        }
        guard let relative = item.iCloudRelativePath?.trimmingCharacters(in: CharacterSet(charactersIn: "/")),
              !relative.isEmpty else {
            return
        }

        guard let containerRoot = fileManager.url(forUbiquityContainerIdentifier: Self.ubiquityContainerIdentifier) else {
            return
        }

        let documentsRoot = containerRoot.appendingPathComponent("Documents", isDirectory: true)
        let destination = documentsRoot.appendingPathComponent(relative, isDirectory: false)
        let expectedChecksum = item.checksumSHA256
        let fileName = item.fileName

        let result = await Task.detached(priority: .utility) { () -> Result<Void, Error> in
            let fm = FileManager.default
            do {
                try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fm.fileExists(atPath: destination.path) {
                    try fm.removeItem(at: destination)
                }
                try fm.copyItem(at: localURL, to: destination)
                if expectedChecksum.isEmpty == false {
                    let localData = try Data(contentsOf: localURL)
                    let destData = try Data(contentsOf: destination)
                    guard localData == destData else {
                        struct ChecksumMismatch: LocalizedError { var errorDescription: String? { "Verifica checksum fallita" } }
                        throw ChecksumMismatch()
                    }
                }
                return .success(())
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success:
            item.isSyncedToICloud = true
            try? modelContext.save()
            recordSyncActivity("Copiato su iCloud: «\(fileName)»")
        case .failure(let error):
            item.isSyncedToICloud = false
            try? modelContext.save()
            recordSyncActivity("Errore iCloud su «\(fileName)»: \(error.localizedDescription)")
        }
    }

    func syncAllPendingDocuments(items: [DocumentItem], modelContext: ModelContext) async {
        guard DocumentsUserSettings.isICloudPDFSyncEnabled else {
            recordSyncActivity("Sync non eseguito: opzione disattivata.")
            return
        }
        guard isUbiquityContainerAvailable else {
            recordSyncActivity("Sync non eseguito: container iCloud non disponibile.")
            return
        }

        let pending = items.filter { $0.localFilePresent && $0.format == .pdf && !$0.isSyncedToICloud }
        guard !pending.isEmpty else {
            recordSyncActivity("Nessun PDF in attesa di copia su iCloud.")
            return
        }

        var succeeded = 0
        var failed = 0
        for doc in pending {
            await syncDocument(doc, modelContext: modelContext)
            if doc.isSyncedToICloud {
                succeeded += 1
            } else {
                failed += 1
            }
        }
        recordSyncActivity("Sync batch: \(succeeded) copiati su iCloud, \(failed) non riusciti.")
    }

    /// Dopo la generazione mensile dei PDF, copia l'archivio del ristorante su iCloud Drive.
    func syncMonthlyArchive(
        restaurantId: UUID,
        restaurantName: String,
        items: [DocumentItem],
        modelContext: ModelContext,
        monthBoundaryCrossed: Bool
    ) async {
        guard DocumentsUserSettings.isICloudPDFSyncEnabled else { return }

        let scoped = items.filter {
            $0.restaurantId == restaurantId && $0.format == .pdf && $0.localFilePresent
        }
        let pendingBefore = scoped.filter { !$0.isSyncedToICloud }.count

        await syncAllPendingDocuments(items: scoped, modelContext: modelContext)
        await pruneRetiredArchiveDirectoriesWhenSafe(
            restaurantDisplayName: restaurantName,
            items: scoped
        )

        let failed = scoped.filter { !$0.isSyncedToICloud }.count
        let copied = max(0, pendingBefore - failed)

        if monthBoundaryCrossed {
            DocumentsUserSettings.setLastMonthlyICloudSync(Date(), restaurantId: restaurantId)
            recordSyncActivity("Archivio mensile sincronizzato su iCloud Drive.")
            ICloudSyncNotificationService.notifyMonthlyArchiveSynced(
                restaurantName: restaurantName,
                copiedCount: copied,
                failedCount: failed
            )
        }
    }

    /// Elimina su iCloud Drive le cartelle mensili ritirate, solo se nessun PDF pendente vi punta ancora.
    func pruneRetiredArchiveDirectoriesWhenSafe(
        restaurantDisplayName: String,
        items: [DocumentItem]
    ) async {
        guard isUbiquityContainerAvailable,
              let container = fileManager.url(forUbiquityContainerIdentifier: Self.ubiquityContainerIdentifier) else {
            return
        }

        let retiredSegments: [String] = {
            var segments: [String] = []
            let period = DocumentArchiveLayout.monthlyPeriodName
            let singoli = DocumentArchiveLayout.singoliGroup
            let combinati = DocumentArchiveLayout.combinatiGroup
            for title in DocumentArchiveLayout.retiredSingoliFolderTitles {
                segments.append("/\(period)/\(singoli)/\(title)/")
            }
            for title in DocumentArchiveLayout.retiredCombinatiFolderTitles {
                segments.append("/\(period)/\(combinati)/\(title)/")
            }
            return segments
        }()

        let hasPendingInRetiredPath = items.contains { item in
            guard !item.isSyncedToICloud, let path = item.iCloudRelativePath else { return false }
            return retiredSegments.contains { path.contains($0) }
        }
        guard !hasPendingInRetiredPath else {
            recordSyncActivity("Pulizia cartelle legacy iCloud rimandata: PDF ancora da ricopiare.")
            return
        }

        let docsRoot = container.appendingPathComponent("Documents", isDirectory: true)
        let safeRestaurant = LocalDocumentStorageService.sanitizeFolderName(restaurantDisplayName)
        let monthlyBase = docsRoot
            .appendingPathComponent("HACCP Manager", isDirectory: true)
            .appendingPathComponent(safeRestaurant, isDirectory: true)
            .appendingPathComponent(DocumentArchiveLayout.monthlyPeriodName, isDirectory: true)

        let removed = await Task.detached(priority: .utility) { () -> Int in
            let fm = FileManager.default
            var count = 0
            for title in DocumentArchiveLayout.retiredSingoliFolderTitles {
                let dir = monthlyBase
                    .appendingPathComponent(DocumentArchiveLayout.singoliGroup, isDirectory: true)
                    .appendingPathComponent(title, isDirectory: true)
                if fm.fileExists(atPath: dir.path), (try? fm.removeItem(at: dir)) != nil {
                    count += 1
                }
            }
            for title in DocumentArchiveLayout.retiredCombinatiFolderTitles {
                let dir = monthlyBase
                    .appendingPathComponent(DocumentArchiveLayout.combinatiGroup, isDirectory: true)
                    .appendingPathComponent(title, isDirectory: true)
                if fm.fileExists(atPath: dir.path), (try? fm.removeItem(at: dir)) != nil {
                    count += 1
                }
            }
            return count
        }.value

        if removed > 0 {
            recordSyncActivity("Rimosse \(removed) cartelle legacy da iCloud Drive.")
        }
    }

    func scheduleSyncAfterGeneration(for itemId: UUID, modelContext: ModelContext) {
        Task { @MainActor in
            let descriptor = FetchDescriptor<DocumentItem>()
            guard let items = try? modelContext.fetch(descriptor),
                  let item = items.first(where: { $0.id == itemId }) else { return }
            await syncDocument(item, modelContext: modelContext)
        }
    }
}
