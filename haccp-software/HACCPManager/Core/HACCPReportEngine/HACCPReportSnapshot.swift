//
//  HACCPReportSnapshot.swift
//  HACCP Manager — Report Engine
//
//  Snapshot JSON per ricostruzione/analytics/backup enterprise.
//  Per ogni report PDF generato l'engine persiste anche uno snapshot strutturato
//  dei dati sorgente: facilita audit, ricostruzioni e migrazioni future.
//

import Foundation
import SwiftData
import CryptoKit

// MARK: - Modello persistente

@Model
final class HACCPReportSnapshot {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID

    var documentItemId: UUID
    var officialDocumentId: String

    var periodRaw: String
    var moduleRaw: String

    var periodStart: Date
    var periodEnd: Date

    var createdAt: Date
    var snapshotSchemaVersion: Int

    var filePath: String
    var sizeInBytes: Int64
    var checksumSHA256: String

    /// Contenuto JSON serializzato (per accesso rapido senza file system).
    @Attribute(.externalStorage) var payload: Data

    var period: HACCPReportPeriod {
        get { HACCPReportPeriod(rawValue: periodRaw) ?? .daily }
        set { periodRaw = newValue.rawValue }
    }

    var module: DocumentModule {
        get { DocumentModule(rawValue: moduleRaw) ?? .haccpCombinato }
        set { moduleRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        documentItemId: UUID,
        officialDocumentId: String,
        period: HACCPReportPeriod,
        module: DocumentModule,
        periodStart: Date,
        periodEnd: Date,
        createdAt: Date = Date(),
        snapshotSchemaVersion: Int = 1,
        filePath: String,
        sizeInBytes: Int64,
        checksumSHA256: String,
        payload: Data
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.documentItemId = documentItemId
        self.officialDocumentId = officialDocumentId
        self.periodRaw = period.rawValue
        self.moduleRaw = module.rawValue
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.createdAt = createdAt
        self.snapshotSchemaVersion = snapshotSchemaVersion
        self.filePath = filePath
        self.sizeInBytes = sizeInBytes
        self.checksumSHA256 = checksumSHA256
        self.payload = payload
    }
}

// MARK: - DTO serializzabili

/// Payload JSON pubblico (versionato, retro-compatibile).
struct HACCPReportSnapshotPayload: Codable {
    let schemaVersion: Int
    let officialDocumentId: String
    let restaurantId: UUID
    let restaurantName: String
    let period: HACCPReportPeriod
    let module: DocumentModule
    let periodStart: Date
    let periodEnd: Date
    let generatedAt: Date
    let generatedByUserId: UUID?
    let generatedByUserName: String
    let appBuild: String

    let receipts: [ReceiptDTO]
    let traceability: [TraceabilityDTO]
    let temperatureLogs: [AuditRowDTO]
    let checklistLogs: [AuditRowDTO]
    let traceabilityLogs: [AuditRowDTO]
    let productions: [ProductionDTO]
    let stats: HACCPReportEngineStats

    struct ReceiptDTO: Codable {
        let id: UUID
        let receivedAt: Date
        let product: String
        let category: String
        let supplier: String
        let lot: String?
        let expiry: Date?
        let temperatureCelsius: Double?
        let minAllowed: Double?
        let maxAllowed: Double?
        let conformityStatus: String
        let temperatureStatus: String
        let notes: String?
        let operatorName: String
    }

    struct TraceabilityDTO: Codable {
        let id: UUID
        let product: String
        let lot: String?
        let supplier: String
        let receivedAt: Date?
        let status: String
        let operatorName: String
    }

    struct AuditRowDTO: Codable {
        let timestamp: Date
        let userName: String
        let module: String
        let action: String
        let entityRef: String
    }

    struct ProductionDTO: Codable {
        let id: UUID
        let title: String
        let createdAt: Date
        let operatorName: String
    }
}

// MARK: - Servizio JSON

/// Persistenza degli snapshot JSON: scrittura file + record SwiftData.
@MainActor
final class HACCPReportSnapshotService {
    static let shared = HACCPReportSnapshotService()
    private init() {}

    private let snapshotFolderName = "Snapshots"

    static let currentSchemaVersion = 1

    // MARK: Persist

    /// Serializza un payload e lo persiste sia su file sia come record SwiftData.
    @discardableResult
    func persist(
        payload: HACCPReportSnapshotPayload,
        document: DocumentItem,
        in modelContext: ModelContext
    ) throws -> HACCPReportSnapshot {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)

        let url = try snapshotURL(for: document)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)

        let checksum = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()

        if let existing = snapshot(for: document.id, in: modelContext) {
            existing.payload = data
            existing.filePath = url.path
            existing.sizeInBytes = Int64(data.count)
            existing.checksumSHA256 = checksum
            existing.createdAt = Date()
            existing.snapshotSchemaVersion = Self.currentSchemaVersion
            existing.period = payload.period
            existing.module = payload.module
            existing.periodStart = payload.periodStart
            existing.periodEnd = payload.periodEnd
            existing.officialDocumentId = payload.officialDocumentId
            try? modelContext.save()
            return existing
        }

        let record = HACCPReportSnapshot(
            restaurantId: document.restaurantId,
            documentItemId: document.id,
            officialDocumentId: payload.officialDocumentId,
            period: payload.period,
            module: payload.module,
            periodStart: payload.periodStart,
            periodEnd: payload.periodEnd,
            snapshotSchemaVersion: Self.currentSchemaVersion,
            filePath: url.path,
            sizeInBytes: Int64(data.count),
            checksumSHA256: checksum,
            payload: data
        )
        modelContext.insert(record)
        try? modelContext.save()
        return record
    }

    // MARK: Query

    func snapshot(for documentItemId: UUID, in modelContext: ModelContext) -> HACCPReportSnapshot? {
        let descriptor = FetchDescriptor<HACCPReportSnapshot>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.first(where: { $0.documentItemId == documentItemId })
    }

    func decoded(snapshot: HACCPReportSnapshot) -> HACCPReportSnapshotPayload? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(HACCPReportSnapshotPayload.self, from: snapshot.payload)
    }

    func snapshots(for restaurantId: UUID, in modelContext: ModelContext) -> [HACCPReportSnapshot] {
        let descriptor = FetchDescriptor<HACCPReportSnapshot>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all
            .filter { $0.restaurantId == restaurantId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Private

    private func snapshotURL(for document: DocumentItem) throws -> URL {
        let storage = try LocalDocumentStorageService.shared.stablePDFDirectory(restaurantId: document.restaurantId)
        let dir = storage
            .deletingLastPathComponent()
            .appendingPathComponent(snapshotFolderName, isDirectory: true)
        let baseName = (document.fileName as NSString).deletingPathExtension
        return dir.appendingPathComponent("\(baseName).json")
    }
}
