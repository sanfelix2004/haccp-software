import Foundation
import SwiftData

/// Astrazione storage documenti (locale + iCloud Drive opzionale).
protocol DocumentStorageServiceProtocol: AnyObject {
    func stablePDFDirectory(restaurantId: UUID) throws -> URL
    func relativePathForICloud(
        restaurantDisplayName: String,
        periodFolder: String,
        groupFolder: String?,
        moduleFolder: String,
        fileName: String
    ) -> String
}

/// Implementazione locale: path stabili sotto Application Support.
protocol LocalDocumentStorageProtocol: DocumentStorageServiceProtocol {}

/// Sincronizzazione **solo PDF** su iCloud Drive (ubiquity). Nessun sync SwiftData.
protocol ICloudDocumentSyncServiceProtocol: AnyObject {
    /// Container iCloud Documenti configurato negli entitlement e disponibile sull’account corrente.
    var isUbiquityContainerAvailable: Bool { get }
    /// Preferenza utente: tentare la copia su iCloud dopo generazione / in batch.
    var isUserPDFSyncEnabled: Bool { get set }

    func syncDocument(_ item: DocumentItem, modelContext: ModelContext) async
    func syncAllPendingDocuments(items: [DocumentItem], modelContext: ModelContext) async
    func scheduleSyncAfterGeneration(for itemId: UUID, modelContext: ModelContext)
    /// Rileggi token/container (es. dopo cambio account iCloud sul dispositivo).
    func refreshConnectionDiagnostics()
}
