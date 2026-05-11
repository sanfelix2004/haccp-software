//
//  HACCPReportEngineMetrics.swift
//  HACCP Manager — Report Engine
//
//  Calcolo metriche aggregate del motore report.
//  Letto da: dashboard "Documenti", header dei PDF, payload JSON degli snapshot.
//

import Foundation
import SwiftData

@MainActor
enum HACCPReportEngineMetrics {

    /// Calcola tutte le metriche del ristorante.
    /// La conformità media è calcolata sull'orizzonte degli ultimi 30 giorni (più rappresentativa).
    static func compute(
        restaurantId: UUID,
        in modelContext: ModelContext,
        referenceDate: Date = Date()
    ) -> HACCPReportEngineStats {
        let receipts = fetch(GoodsReceipt.self, in: modelContext, restaurantId: restaurantId, keyPath: \.restaurantId)
        let traceability = fetch(TraceabilityRecord.self, in: modelContext, restaurantId: restaurantId, keyPath: \.restaurantId)
        let documents = fetch(DocumentItem.self, in: modelContext, restaurantId: restaurantId, keyPath: \.restaurantId)
        let temperatureAlerts = fetchTemperatureAlerts(restaurantId: restaurantId, in: modelContext)

        let calendar = Calendar.current
        let todayInterval = calendar.dateInterval(of: .day, for: referenceDate)
            ?? DateInterval(start: calendar.startOfDay(for: referenceDate), duration: 86400)
        let windowStart = calendar.date(byAdding: .day, value: -30, to: referenceDate) ?? referenceDate
        let conformityWindow = DateInterval(start: windowStart, end: referenceDate)

        let generatedToday = documents.filter { todayInterval.contains($0.generatedAt) }.count
        let pendingSync = documents.filter { $0.format == .pdf && !$0.isSyncedToICloud && $0.localFilePresent }.count
        let syncedSync = documents.filter { $0.format == .pdf && $0.isSyncedToICloud && $0.localFilePresent }.count
        let lastGenerated = documents.map(\.generatedAt).max()

        let openReceiptsNonCompliant = receipts.filter { receipt in
            isReceiptOpenNonCompliant(receipt)
        }.count

        let openTraceabilityNonCompliant = traceability.filter { trace in
            trace.isNonCompliant && trace.nonComplianceResolvedAt == nil
        }.count

        let totalOpenNC = openReceiptsNonCompliant + openTraceabilityNonCompliant
        let alerts = temperatureAlerts.filter { $0.isActive }.count

        let recentReceipts = receipts.filter { conformityWindow.contains($0.receivedAt) }
        let conformity: Double = {
            guard !recentReceipts.isEmpty else { return 1.0 }
            let okCount = recentReceipts.filter { $0.status == .conforme || $0.status == .acceptedWithNotes }.count
            return Double(okCount) / Double(recentReceipts.count)
        }()

        return HACCPReportEngineStats(
            totalReports: documents.count,
            generatedToday: generatedToday,
            pendingCloudSync: pendingSync,
            syncedToCloud: syncedSync,
            openNonConformities: totalOpenNC,
            temperatureAlerts: alerts,
            conformityAverage: conformity,
            lastGeneratedAt: lastGenerated
        )
    }

    /// Conformità di un singolo periodo arbitrario (per snapshot JSON).
    static func periodConformity(
        interval: DateInterval,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord]
    ) -> HACCPConformityLevel {
        let inWindowReceipts = receipts.filter { interval.contains($0.receivedAt) }
        let inWindowTrace = traceability.filter { interval.contains($0.receivedAt) }
        let openNC = inWindowReceipts.filter { isReceiptOpenNonCompliant($0) }.count
            + inWindowTrace.filter { $0.isNonCompliant && $0.nonComplianceResolvedAt == nil }.count
        let total = inWindowReceipts.count + inWindowTrace.count
        guard total > 0 else { return .nonValutato }
        if openNC == 0 { return .conforme }
        if Double(openNC) / Double(total) > 0.15 { return .critico }
        return .attenzione
    }

    // MARK: - Private helpers

    private static func isReceiptOpenNonCompliant(_ receipt: GoodsReceipt) -> Bool {
        let opened = receipt.status == .nonConforme || receipt.status == .rejected
        return opened && receipt.nonComplianceResolvedAt == nil
    }

    private static func fetch<T: PersistentModel>(
        _ type: T.Type,
        in modelContext: ModelContext,
        restaurantId: UUID,
        keyPath: KeyPath<T, UUID>
    ) -> [T] {
        let descriptor = FetchDescriptor<T>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0[keyPath: keyPath] == restaurantId }
    }

    private static func fetchTemperatureAlerts(restaurantId: UUID, in modelContext: ModelContext) -> [TemperatureAlert] {
        let descriptor = FetchDescriptor<TemperatureAlert>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.restaurantId == restaurantId }
    }
}
