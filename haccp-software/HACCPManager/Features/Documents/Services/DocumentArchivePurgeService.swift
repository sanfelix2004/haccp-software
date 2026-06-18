import Foundation
import SwiftData

/// Pulizia completa archivio PDF (file + record SwiftData) con rigenerazione automatica.
enum DocumentArchivePurgeService {
    static let markerFileName = "HACCP_PURGE_DOCUMENTS.request"
    private static let needsRegenerationKey = "DocumentArchivePurgeService.needsRegeneration"

    private static var applicationSupportURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    static func markerURL() -> URL? {
        applicationSupportURL?.appendingPathComponent(markerFileName)
    }

    /// Legge il marker creato dallo script shell e pulisce file + record (senza login).
    @MainActor
    static func consumeMarkerAndPurgeIfNeeded(modelContext: ModelContext) {
        guard let url = markerURL(), FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)

        purgeAllPDFFiles()
        deleteAllDocumentItems(modelContext: modelContext)
        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: needsRegenerationKey)
    }

    /// Rigenera l'archivio dopo purge (richiede ristorante e utente attivi).
    @MainActor
    static func regenerateArchiveIfNeeded(
        modelContext: ModelContext,
        restaurant: Restaurant,
        user: LocalUser
    ) async {
        guard UserDefaults.standard.bool(forKey: needsRegenerationKey) else { return }
        UserDefaults.standard.set(false, forKey: needsRegenerationKey)

        await HACCPReportEngine.shared.runFullArchive(
            restaurant: restaurant,
            user: user,
            in: modelContext,
            force: true
        )
        HACCPReportEngine.shared.refreshStats(restaurantId: restaurant.id, in: modelContext)
    }

    static func purgeAllPDFFiles() {
        let fm = FileManager.default
        guard let support = applicationSupportURL else { return }

        let haccpRoot = support.appendingPathComponent("HACCPManager", isDirectory: true)
        if fm.fileExists(atPath: haccpRoot.path) {
            try? fm.removeItem(at: haccpRoot)
        }

        let temp = support.appendingPathComponent("HACCPDocumentiEsportazioneTemp", isDirectory: true)
        if fm.fileExists(atPath: temp.path) {
            try? fm.removeItem(at: temp)
        }
    }

    static func deleteAllDocumentItems(modelContext: ModelContext) {
        let all = (try? modelContext.fetch(FetchDescriptor<DocumentItem>())) ?? []
        for item in all {
            if !item.filePath.isEmpty, FileManager.default.fileExists(atPath: item.filePath) {
                try? FileManager.default.removeItem(atPath: item.filePath)
            }
            modelContext.delete(item)
        }
    }

    /// Pulizia immediata (da UI MASTER): file + record + rigenerazione.
    @MainActor
    static func purgeAndRegenerateArchive(
        restaurant: Restaurant,
        user: LocalUser,
        modelContext: ModelContext
    ) async {
        purgeAllPDFFiles()
        deleteAllDocumentItems(modelContext: modelContext)
        try? modelContext.save()
        await HACCPReportEngine.shared.runFullArchive(
            restaurant: restaurant,
            user: user,
            in: modelContext,
            force: true
        )
        HACCPReportEngine.shared.refreshStats(restaurantId: restaurant.id, in: modelContext)
    }
}
