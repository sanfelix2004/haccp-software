//
//  HACCPReportEngine.swift
//  HACCP Manager — Report Engine
//
//  Facade centrale del motore report HACCP.
//
//  Responsabilità:
//   1. Orchestrare la generazione automatica dei documenti tramite `DocumentGenerationService`.
//   2. Catturare snapshot JSON e revisioni v1/v2/vN ad ogni rigenerazione.
//   3. Tracciare l'attività in audit trail (`HACCPAuditManager`).
//   4. Esporre statistiche pronte per la dashboard.
//
//  Non duplica logica: delega al renderer / storage / sync esistenti.
//

import Foundation
import SwiftData
import CryptoKit
import Combine

@MainActor
final class HACCPReportEngine: ObservableObject {

    static let shared = HACCPReportEngine()

    // MARK: Published state (per dashboard)

    @Published private(set) var lastRunAt: Date?
    @Published private(set) var lastRunSummary: String = ""
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var currentStats: HACCPReportEngineStats = .zero

    private init() {}

    // MARK: Configuration

    /// Numero minimo di secondi fra due esecuzioni complete del motore (anti-spam su scene-phase).
    var minimumIntervalBetweenRunsSeconds: TimeInterval = 60

    /// Indica se l'archivio è già stato eseguito di recente (debounce su scenePhase).
    var canRunNow: Bool {
        guard let last = lastRunAt else { return true }
        return Date().timeIntervalSince(last) >= minimumIntervalBetweenRunsSeconds
    }

    // MARK: - Pipeline principale

    /// Sincronizza l'archivio completo (delega al `DocumentGenerationService`),
    /// poi cattura snapshot JSON + revisioni v1/v2 e registra l'evento in audit.
    func runFullArchive(
        restaurant: Restaurant,
        user: LocalUser,
        in modelContext: ModelContext,
        force: Bool = false
    ) async {
        if isRunning { return }
        if !force, !canRunNow { return }
        isRunning = true
        defer { isRunning = false }

        let receipts = fetchReceipts(in: modelContext, restaurantId: restaurant.id)
        let traceability = fetchTraceability(in: modelContext, restaurantId: restaurant.id)
        let images = fetchAllImages(in: modelContext)
        let productions = fetchProductions(in: modelContext, restaurantId: restaurant.id)
        let links = fetchAllLinks(in: modelContext)
        let logs = fetchAllTraceabilityLogs(in: modelContext)
        let checklistLogs = fetchChecklistLogs(in: modelContext, restaurantId: restaurant.id)
        let temperatureLogs = fetchTemperatureLogs(in: modelContext, restaurantId: restaurant.id)

        let before = fetchDocuments(in: modelContext, restaurantId: restaurant.id)
        let beforeIds = Set(before.map(\.id))

        DocumentGenerationService.shared.syncArchive(
            restaurant: restaurant,
            user: user,
            receipts: receipts,
            traceabilityRecords: traceability,
            traceabilityImages: images,
            productions: productions,
            traceabilityLinks: links,
            traceabilityLogs: logs,
            checklistAuditLogs: checklistLogs,
            temperatureAuditLogs: temperatureLogs,
            modelContext: modelContext
        )

        let after = fetchDocuments(in: modelContext, restaurantId: restaurant.id)
        let newOrUpdated = after.filter { doc in
            !beforeIds.contains(doc.id) ||
            (before.first(where: { $0.id == doc.id })?.checksumSHA256 ?? "") != doc.checksumSHA256
        }

        var snapshotsCreated = 0
        var revisionsCreated = 0
        for doc in newOrUpdated where doc.status == .generato && doc.localFilePresent {
            if captureSnapshotAndRevision(
                for: doc,
                restaurant: restaurant,
                user: user,
                receipts: receipts,
                traceability: traceability,
                productions: productions,
                checklistLogs: checklistLogs,
                temperatureLogs: temperatureLogs,
                traceabilityLogs: logs,
                in: modelContext
            ) {
                snapshotsCreated += 1
                revisionsCreated += 1
            }
        }

        HACCPAuditManager.shared.record(
            in: modelContext,
            restaurantId: restaurant.id,
            action: .generate,
            severity: .info,
            module: "REPORT_ENGINE",
            subject: "FULL_ARCHIVE",
            entityRef: restaurant.name,
            user: user,
            details: "Documenti totali: \(after.count). Nuovi/aggiornati: \(newOrUpdated.count). Snapshots: \(snapshotsCreated). Revisioni: \(revisionsCreated)."
        )

        refreshStats(restaurantId: restaurant.id, in: modelContext)

        lastRunAt = Date()
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        lastRunSummary = "Ultimo run: \(df.string(from: lastRunAt!)) · \(newOrUpdated.count) doc aggiornati · \(snapshotsCreated) snapshot JSON · \(revisionsCreated) revisioni"
    }

    // MARK: - Rigenerazione manuale (con audit + revisione)

    func regenerate(
        document: DocumentItem,
        restaurant: Restaurant,
        user: LocalUser,
        reason: String = "Rigenerazione manuale",
        in modelContext: ModelContext
    ) throws {
        let receipts = fetchReceipts(in: modelContext, restaurantId: restaurant.id)
        let traceability = fetchTraceability(in: modelContext, restaurantId: restaurant.id)
        let images = fetchAllImages(in: modelContext)
        let productions = fetchProductions(in: modelContext, restaurantId: restaurant.id)
        let links = fetchAllLinks(in: modelContext)
        let logs = fetchAllTraceabilityLogs(in: modelContext)
        let checklistLogs = fetchChecklistLogs(in: modelContext, restaurantId: restaurant.id)
        let temperatureLogs = fetchTemperatureLogs(in: modelContext, restaurantId: restaurant.id)
        let folders = fetchAllFolders(in: modelContext)
        let allItems = fetchDocuments(in: modelContext, restaurantId: restaurant.id)

        try DocumentGenerationService.shared.regenerateDocument(
            document,
            restaurant: restaurant,
            user: user,
            folders: folders,
            receipts: receipts,
            traceabilityRecords: traceability,
            traceabilityImages: images,
            productions: productions,
            traceabilityLinks: links,
            traceabilityLogs: logs,
            checklistAuditLogs: checklistLogs,
            temperatureAuditLogs: temperatureLogs,
            allDocumentItems: allItems,
            modelContext: modelContext
        )

        _ = captureSnapshotAndRevision(
            for: document,
            restaurant: restaurant,
            user: user,
            receipts: receipts,
            traceability: traceability,
            productions: productions,
            checklistLogs: checklistLogs,
            temperatureLogs: temperatureLogs,
            traceabilityLogs: logs,
            reason: reason,
            in: modelContext
        )
    }

    // MARK: - Statistiche

    func refreshStats(restaurantId: UUID, in modelContext: ModelContext) {
        currentStats = HACCPReportEngineMetrics.compute(restaurantId: restaurantId, in: modelContext)
    }

    // MARK: - Snapshot + revisione (interno)

    @discardableResult
    private func captureSnapshotAndRevision(
        for document: DocumentItem,
        restaurant: Restaurant,
        user: LocalUser,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        productions: [Production],
        checklistLogs: [ChecklistAuditLog],
        temperatureLogs: [TemperatureAuditLog],
        traceabilityLogs: [TraceabilityLog],
        reason: String = "Rigenerazione automatica",
        in modelContext: ModelContext
    ) -> Bool {
        guard document.localFilePresent,
              FileManager.default.fileExists(atPath: document.filePath) else {
            return false
        }
        guard let periodStart = document.periodStart, let periodEnd = document.periodEnd else { return false }
        let interval = DateInterval(start: periodStart, end: periodEnd.addingTimeInterval(1))
        let period = enginePeriod(for: document)

        let payload = makeSnapshotPayload(
            document: document,
            restaurant: restaurant,
            user: user,
            period: period,
            interval: interval,
            receipts: receipts,
            traceability: traceability,
            productions: productions,
            checklistLogs: checklistLogs,
            temperatureLogs: temperatureLogs,
            traceabilityLogs: traceabilityLogs
        )

        // Persist snapshot (file + record).
        _ = try? HACCPReportSnapshotService.shared.persist(
            payload: payload,
            document: document,
            in: modelContext
        )

        // Cattura revisione (vN) se il fingerprint è cambiato.
        let fingerprint = sourceFingerprint(
            checksum: document.checksumSHA256,
            receipts: receipts,
            traceability: traceability,
            interval: interval
        )
        _ = HACCPHistoryManager.shared.captureRevision(
            for: document,
            sourceFingerprint: fingerprint,
            reason: reason,
            user: user,
            in: modelContext
        )

        return true
    }

    // MARK: - Builders

    private func makeSnapshotPayload(
        document: DocumentItem,
        restaurant: Restaurant,
        user: LocalUser,
        period: HACCPReportPeriod,
        interval: DateInterval,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        productions: [Production],
        checklistLogs: [ChecklistAuditLog],
        temperatureLogs: [TemperatureAuditLog],
        traceabilityLogs: [TraceabilityLog]
    ) -> HACCPReportSnapshotPayload {
        let receiptsInWindow = receipts.filter { interval.contains($0.receivedAt) }
        let traceInWindow = traceability.filter { interval.contains($0.receivedAt) }
        let productionsInWindow = productions.filter { interval.contains($0.createdAt) }

        let receiptDTOs: [HACCPReportSnapshotPayload.ReceiptDTO] = receiptsInWindow.map { r in
            HACCPReportSnapshotPayload.ReceiptDTO(
                id: r.id,
                receivedAt: r.receivedAt,
                product: r.productNameSnapshot,
                category: r.category.rawValue,
                supplier: r.supplierNameSnapshot,
                lot: r.lotNumber,
                expiry: r.expiryDate,
                temperatureCelsius: r.temperatureValue,
                minAllowed: r.minAllowed,
                maxAllowed: r.maxAllowed,
                conformityStatus: r.status.rawValue,
                temperatureStatus: r.temperatureStatus.rawValue,
                notes: r.notes,
                operatorName: r.createdByNameSnapshot
            )
        }

        let traceDTOs: [HACCPReportSnapshotPayload.TraceabilityDTO] = traceInWindow.map { t in
            HACCPReportSnapshotPayload.TraceabilityDTO(
                id: t.id,
                product: t.productName,
                lot: t.lotCode,
                supplier: t.supplier,
                receivedAt: t.receivedAt,
                status: t.productStatus.rawValue,
                operatorName: t.createdByNameSnapshot
            )
        }

        let tempDTOs: [HACCPReportSnapshotPayload.AuditRowDTO] = temperatureLogs
            .filter { interval.contains($0.createdAt) }
            .map { log in
                HACCPReportSnapshotPayload.AuditRowDTO(
                    timestamp: log.createdAt,
                    userName: log.userName,
                    module: "Temperatura",
                    action: log.action,
                    entityRef: log.deviceName
                )
            }

        let checklistDTOs: [HACCPReportSnapshotPayload.AuditRowDTO] = checklistLogs
            .filter { interval.contains($0.timestamp) }
            .map { log in
                HACCPReportSnapshotPayload.AuditRowDTO(
                    timestamp: log.timestamp,
                    userName: log.userName,
                    module: log.module,
                    action: log.action,
                    entityRef: String(log.entityId.uuidString.prefix(8)).uppercased()
                )
            }

        let traceLogDTOs: [HACCPReportSnapshotPayload.AuditRowDTO] = traceabilityLogs
            .filter { interval.contains($0.timestamp) }
            .map { log in
                HACCPReportSnapshotPayload.AuditRowDTO(
                    timestamp: log.timestamp,
                    userName: log.operatorName,
                    module: "Tracciabilità",
                    action: String(describing: log.actionType),
                    entityRef: String(log.receivedItemId.uuidString.prefix(8)).uppercased()
                )
            }

        let prodDTOs: [HACCPReportSnapshotPayload.ProductionDTO] = productionsInWindow.map { p in
            HACCPReportSnapshotPayload.ProductionDTO(
                id: p.id,
                title: p.name,
                createdAt: p.createdAt,
                operatorName: p.categoryNameSnapshot
            )
        }

        // Statistiche al volo (allineate alla dashboard).
        let openNC = receiptsInWindow.filter {
            ($0.status == .nonConforme || $0.status == .rejected) && $0.nonComplianceResolvedAt == nil
        }.count + traceInWindow.filter { $0.isNonCompliant && $0.nonComplianceResolvedAt == nil }.count

        let conformity: Double = {
            guard !receiptsInWindow.isEmpty else { return 1.0 }
            let okCount = receiptsInWindow.filter { $0.status == .conforme || $0.status == .acceptedWithNotes }.count
            return Double(okCount) / Double(receiptsInWindow.count)
        }()

        let stats = HACCPReportEngineStats(
            totalReports: 1,
            generatedToday: 1,
            pendingCloudSync: 0,
            syncedToCloud: 0,
            openNonConformities: openNC,
            temperatureAlerts: 0,
            conformityAverage: conformity,
            lastGeneratedAt: document.generatedAt
        )

        return HACCPReportSnapshotPayload(
            schemaVersion: HACCPReportSnapshotService.currentSchemaVersion,
            officialDocumentId: document.officialDocumentId,
            restaurantId: restaurant.id,
            restaurantName: restaurant.name,
            period: period,
            module: document.module,
            periodStart: interval.start,
            periodEnd: interval.end.addingTimeInterval(-1),
            generatedAt: document.generatedAt,
            generatedByUserId: user.id,
            generatedByUserName: user.name,
            appBuild: HACCPAppBuildVersion.marketingAndBuild,
            receipts: receiptDTOs,
            traceability: traceDTOs,
            temperatureLogs: tempDTOs,
            checklistLogs: checklistDTOs,
            traceabilityLogs: traceLogDTOs,
            productions: prodDTOs,
            stats: stats
        )
    }

    private func sourceFingerprint(
        checksum: String,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        interval: DateInterval
    ) -> String {
        var inputs: [String] = []
        inputs.append("checksum:\(checksum)")
        inputs.append("rcount:\(receipts.filter { interval.contains($0.receivedAt) }.count)")
        inputs.append("tcount:\(traceability.filter { interval.contains($0.receivedAt) }.count)")
        for r in receipts.filter({ interval.contains($0.receivedAt) }).sorted(by: { $0.receivedAt < $1.receivedAt }) {
            inputs.append("r:\(r.id):\(r.statusRaw):\(r.temperatureValue ?? 0)")
        }
        for t in traceability.filter({ interval.contains($0.receivedAt) }).sorted(by: { $0.receivedAt < $1.receivedAt }) {
            inputs.append("t:\(t.id):\(t.productStatusRaw):\(t.isNonCompliant ? "NC" : "OK")")
        }
        return HACCPHistoryManager.sourceFingerprint(inputs)
    }

    private func enginePeriod(for document: DocumentItem) -> HACCPReportPeriod {
        switch document.type {
        case .giornaliero: return .daily
        case .settimanale: return .weekly
        case .mensile: return .monthly
        case .annuale: return .yearly
        case .nonConformita: return .nonConformity
        default: return .daily
        }
    }

    // MARK: - Fetch helpers (specifici per modello, evitano Mirror su @Model)

    private func fetchReceipts(in modelContext: ModelContext, restaurantId: UUID) -> [GoodsReceipt] {
        let all = (try? modelContext.fetch(FetchDescriptor<GoodsReceipt>())) ?? []
        return all.filter { $0.restaurantId == restaurantId }
    }

    private func fetchTraceability(in modelContext: ModelContext, restaurantId: UUID) -> [TraceabilityRecord] {
        let all = (try? modelContext.fetch(FetchDescriptor<TraceabilityRecord>())) ?? []
        return all.filter { $0.restaurantId == restaurantId }
    }

    private func fetchProductions(in modelContext: ModelContext, restaurantId: UUID) -> [Production] {
        let all = (try? modelContext.fetch(FetchDescriptor<Production>())) ?? []
        return all.filter { $0.restaurantId == restaurantId }
    }

    private func fetchChecklistLogs(in modelContext: ModelContext, restaurantId: UUID) -> [ChecklistAuditLog] {
        let all = (try? modelContext.fetch(FetchDescriptor<ChecklistAuditLog>())) ?? []
        return all.filter { $0.restaurantId == restaurantId }
    }

    private func fetchTemperatureLogs(in modelContext: ModelContext, restaurantId: UUID) -> [TemperatureAuditLog] {
        let all = (try? modelContext.fetch(FetchDescriptor<TemperatureAuditLog>())) ?? []
        return all.filter { $0.restaurantId == restaurantId }
    }

    private func fetchDocuments(in modelContext: ModelContext, restaurantId: UUID) -> [DocumentItem] {
        let all = (try? modelContext.fetch(FetchDescriptor<DocumentItem>())) ?? []
        return all.filter { $0.restaurantId == restaurantId }
    }

    private func fetchAllImages(in modelContext: ModelContext) -> [ProductImage] {
        let descriptor = FetchDescriptor<ProductImage>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllLinks(in modelContext: ModelContext) -> [TraceabilityLink] {
        let descriptor = FetchDescriptor<TraceabilityLink>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllTraceabilityLogs(in modelContext: ModelContext) -> [TraceabilityLog] {
        let descriptor = FetchDescriptor<TraceabilityLog>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllFolders(in modelContext: ModelContext) -> [DocumentFolder] {
        let descriptor = FetchDescriptor<DocumentFolder>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
