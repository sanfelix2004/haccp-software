//
//  HACCPReportRevision.swift
//  HACCP Manager — Report Engine
//
//  Gestione delle revisioni dei report. Quando un report viene rigenerato perché
//  i dati sorgente sono cambiati, l'engine **non** sovrascrive il PDF storico:
//  crea una nuova revisione (`v2`, `v3`, …) e mantiene la copia originale firmata.
//
//  Naming file finale: `<base>_v<N>.pdf` (es. `Report_Daily_2026_05_02_v1.pdf`).
//

import Foundation
import SwiftData
import CryptoKit

@Model
final class HACCPReportRevision {
    @Attribute(.unique) var id: UUID

    var restaurantId: UUID

    /// Documento principale a cui questa revisione si riferisce (`DocumentItem.id`).
    var documentItemId: UUID
    /// Numero di revisione (1, 2, 3, …).
    var revisionNumber: Int
    /// Indica se questa revisione è la "head" attualmente attiva (l'ultima).
    var isCurrent: Bool

    /// Identificativo ufficiale stabile del report (es. `HACCP-DOC-…`).
    var officialDocumentId: String
    /// Nome file della revisione (con suffisso `_vN`).
    var fileName: String
    /// Path locale stabile della copia archiviata.
    var archivedFilePath: String
    /// SHA-256 della copia archiviata.
    var checksumSHA256: String
    /// Dimensione file in byte.
    var sizeInBytes: Int64
    /// Versione build app al momento della revisione.
    var documentBuildVersion: String

    /// Hash dei dati sorgente al momento della revisione (per detect di cambiamenti).
    var sourceFingerprint: String

    var createdAt: Date
    var createdByUserId: UUID?
    var createdByNameSnapshot: String

    /// Motivo della revisione (libero, es. "rigenerazione automatica", "regola modificata").
    var reason: String

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        documentItemId: UUID,
        revisionNumber: Int,
        isCurrent: Bool = true,
        officialDocumentId: String,
        fileName: String,
        archivedFilePath: String,
        checksumSHA256: String,
        sizeInBytes: Int64,
        documentBuildVersion: String,
        sourceFingerprint: String,
        createdAt: Date = Date(),
        createdByUserId: UUID? = nil,
        createdByNameSnapshot: String = "",
        reason: String = ""
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.documentItemId = documentItemId
        self.revisionNumber = revisionNumber
        self.isCurrent = isCurrent
        self.officialDocumentId = officialDocumentId
        self.fileName = fileName
        self.archivedFilePath = archivedFilePath
        self.checksumSHA256 = checksumSHA256
        self.sizeInBytes = sizeInBytes
        self.documentBuildVersion = documentBuildVersion
        self.sourceFingerprint = sourceFingerprint
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.reason = reason
    }
}

// MARK: - History Manager

/// Manutiene la cronologia delle revisioni dei report PDF.
/// Una revisione viene archiviata copiando il PDF attivo in una sotto-cartella `Revisions/`,
/// così che il PDF "ufficiale" attuale resti accessibile col nome canonico.
@MainActor
final class HACCPHistoryManager {
    static let shared = HACCPHistoryManager()
    private init() {}

    private let revisionFolderName = "Revisions"

    // MARK: Public API

    /// Numero di revisioni esistenti per un documento.
    func revisionCount(
        in modelContext: ModelContext,
        documentItemId: UUID
    ) -> Int {
        revisions(in: modelContext, documentItemId: documentItemId).count
    }

    /// Restituisce tutte le revisioni di un documento, ordinate per `revisionNumber` crescente.
    func revisions(
        in modelContext: ModelContext,
        documentItemId: UUID
    ) -> [HACCPReportRevision] {
        let descriptor = FetchDescriptor<HACCPReportRevision>()
        guard let all = try? modelContext.fetch(descriptor) else { return [] }
        return all
            .filter { $0.documentItemId == documentItemId }
            .sorted { $0.revisionNumber < $1.revisionNumber }
    }

    func currentRevision(
        in modelContext: ModelContext,
        documentItemId: UUID
    ) -> HACCPReportRevision? {
        revisions(in: modelContext, documentItemId: documentItemId)
            .last(where: { $0.isCurrent })
    }

    /// Calcola il "fingerprint" deterministico dei dati sorgente di un report.
    /// Se è diverso dall'ultima revisione, la rigenerazione produce una nuova versione.
    static func sourceFingerprint(_ inputs: [String]) -> String {
        let joined = inputs.joined(separator: "|")
        let digest = SHA256.hash(data: Data(joined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Snapshot operations

    /// Cattura il PDF attuale di un `DocumentItem` come una nuova revisione (`vN`).
    /// Restituisce la revisione creata, o `nil` se nulla è cambiato rispetto alla `head`.
    @discardableResult
    func captureRevision(
        for item: DocumentItem,
        sourceFingerprint: String,
        reason: String,
        user: LocalUser?,
        in modelContext: ModelContext
    ) -> HACCPReportRevision? {
        let fm = FileManager.default

        // Senza PDF locale non posso archiviare nulla.
        guard item.localFilePresent,
              fm.fileExists(atPath: item.filePath),
              let pdfData = try? Data(contentsOf: URL(fileURLWithPath: item.filePath)) else {
            return nil
        }

        let existing = revisions(in: modelContext, documentItemId: item.id)
        // No-op se il fingerprint è identico all'ultima revisione vigente.
        if let head = existing.last(where: { $0.isCurrent }), head.sourceFingerprint == sourceFingerprint {
            return nil
        }

        // Disattiva la "head" precedente (le revisioni passate restano consultabili).
        for rev in existing where rev.isCurrent {
            rev.isCurrent = false
        }

        let nextNumber = (existing.map(\.revisionNumber).max() ?? 0) + 1
        let archivedURL = try? archivedURL(for: item, revisionNumber: nextNumber)
        guard let dest = archivedURL else { return nil }

        do {
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
            try pdfData.write(to: dest, options: .atomic)
        } catch {
            return nil
        }

        let checksum = sha256Hex(pdfData)
        let buildLabel: String = {
            return HACCPAppBuildVersion.marketingAndBuild
        }()

        let revFileName = dest.lastPathComponent
        let revision = HACCPReportRevision(
            restaurantId: item.restaurantId,
            documentItemId: item.id,
            revisionNumber: nextNumber,
            isCurrent: true,
            officialDocumentId: item.officialDocumentId,
            fileName: revFileName,
            archivedFilePath: dest.path,
            checksumSHA256: checksum,
            sizeInBytes: Int64(pdfData.count),
            documentBuildVersion: buildLabel,
            sourceFingerprint: sourceFingerprint,
            createdByUserId: user?.id,
            createdByNameSnapshot: user?.name ?? "",
            reason: reason
        )
        modelContext.insert(revision)
        try? modelContext.save()

        HACCPAuditManager.shared.record(
            in: modelContext,
            restaurantId: item.restaurantId,
            action: .regenerate,
            severity: nextNumber == 1 ? .info : .warning,
            module: "REPORT_REVISION",
            subject: "v\(nextNumber)",
            entityId: item.id,
            entityRef: revFileName,
            user: user,
            previousValue: existing.last(where: { !$0.isCurrent }).map { "v\($0.revisionNumber)" },
            newValue: "v\(nextNumber)",
            details: reason
        )

        return revision
    }

    // MARK: Private

    private func archivedURL(for item: DocumentItem, revisionNumber: Int) throws -> URL {
        let storage = try LocalDocumentStorageService.shared.stablePDFDirectory(restaurantId: item.restaurantId)
        let dir = storage.appendingPathComponent(revisionFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let base = (item.fileName as NSString).deletingPathExtension
        let ext = (item.fileName as NSString).pathExtension.isEmpty ? "pdf" : (item.fileName as NSString).pathExtension
        let revName = "\(base)_v\(revisionNumber).\(ext)"
        return dir.appendingPathComponent(revName)
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
