//
//  ActiveBlastChillingManager.swift
//  Stato globale abbattimenti in corso (overlay). Cronometri UI via LiveProcessDurationText.
//

import Foundation
import SwiftData
import Combine

struct ActiveBlastSnapshot: Identifiable, Equatable {
    let id: UUID
    let productionId: UUID?
    let productionName: String
    let categoryName: String
    let startedAt: Date
    let initialTemperature: Double
    let targetTemperature: Double
    let operatorName: String

    init(record: BlastChillingRecord) {
        id = record.id
        productionId = record.productionId
        productionName = record.productionNameSnapshot
        categoryName = record.productionCategorySnapshot
        startedAt = record.startedAt
        initialTemperature = record.initialTemperature
        targetTemperature = record.targetTemperature
        operatorName = record.createdByNameSnapshot
    }

    func isOverRecommended(at now: Date) -> Bool {
        BlastChillingDurationFormatter.isOverRecommendedDuration(since: startedAt, now: now)
    }
}

@MainActor
final class ActiveBlastChillingManager: ObservableObject {

    static let shared = ActiveBlastChillingManager()

    private static let maxActiveFetch = 32

    @Published private(set) var activeSnapshots: [ActiveBlastSnapshot] = []
    @Published var showActiveListSheet = false
    @Published var recordIdPendingComplete: UUID?
    @Published var errorMessage: String?

    private let service = BlastChillingService()

    private init() {}

    var hasActiveBlasts: Bool { !activeSnapshots.isEmpty }

    var primarySnapshot: ActiveBlastSnapshot? { activeSnapshots.first }

    var collapsedTitle: String {
        switch activeSnapshots.count {
        case 0: return ""
        case 1: return "Abbattimento"
        default: return "\(activeSnapshots.count) abbattimenti attivi"
        }
    }

    var collapsedSubtitle: String { "Tocca per terminare" }

    func reset() {
        clearActiveState()
        recordIdPendingComplete = nil
        errorMessage = nil
    }

    func refresh(context: ModelContext, restaurantId: UUID?) {
        guard let restaurantId else {
            recordIdPendingComplete = nil
            clearActiveState()
            return
        }

        reconcilePendingComplete(context: context, restaurantId: restaurantId)

        guard let records = fetchActiveRecords(context: context, restaurantId: restaurantId) else {
            return
        }
        applyActiveRecords(records)
        reconcilePendingComplete(context: context, restaurantId: restaurantId)
    }

    func fetchRecord(id: UUID, restaurantId: UUID, context: ModelContext) -> BlastChillingRecord? {
        let rid = restaurantId
        let targetId = id
        var descriptor = FetchDescriptor<BlastChillingRecord>(
            predicate: #Predicate { $0.id == targetId && $0.restaurantId == rid }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func production(for record: BlastChillingRecord) -> Production {
        Production(
            id: record.productionId ?? record.traceabilityItemId ?? record.id,
            restaurantId: record.restaurantId,
            name: record.productionNameSnapshot,
            categoryId: record.productionId ?? record.id,
            categoryNameSnapshot: record.productionCategorySnapshot,
            isCustom: record.productionId == nil
        )
    }

    func complete(
        record: BlastChillingRecord,
        endedAt: Date,
        finalTemperature: Double,
        notes: String?,
        correctiveAction: String?,
        context: ModelContext
    ) {
        do {
            try service.completeRecord(
                record,
                endedAt: endedAt,
                finalTemperature: finalTemperature,
                notes: notes,
                correctiveAction: correctiveAction,
                modelContext: context
            )
            recordIdPendingComplete = nil
            refresh(context: context, restaurantId: record.restaurantId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancel(record: BlastChillingRecord, context: ModelContext) {
        do {
            try service.cancelRecord(record, modelContext: context)
            if recordIdPendingComplete == record.id {
                recordIdPendingComplete = nil
            }
            refresh(context: context, restaurantId: record.restaurantId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private

    private func fetchActiveRecords(
        context: ModelContext,
        restaurantId: UUID
    ) -> [BlastChillingRecord]? {
        let rid = restaurantId
        let inCorsoStatus = BlastChillingStatus.inCorso.rawValue

        var descriptor = FetchDescriptor<BlastChillingRecord>(
            predicate: #Predicate { record in
                record.restaurantId == rid
                    && !record.isArchived
                    && record.endedAt == nil
                    && record.statusRaw == inCorsoStatus
            },
            sortBy: [SortDescriptor(\BlastChillingRecord.startedAt)]
        )
        descriptor.fetchLimit = Self.maxActiveFetch

        do {
            return try context.fetch(descriptor).filter(\.isActive)
        } catch {
            return nil
        }
    }

    private func applyActiveRecords(_ records: [BlastChillingRecord]) {
        let newSnapshots = records.map(ActiveBlastSnapshot.init(record:))
        if newSnapshots.isEmpty {
            clearActiveState()
            return
        }
        if newSnapshots == activeSnapshots { return }
        activeSnapshots = newSnapshots
    }

    private func clearActiveState() {
        guard !activeSnapshots.isEmpty else {
            showActiveListSheet = false
            return
        }
        activeSnapshots = []
        showActiveListSheet = false
    }

    private func reconcilePendingComplete(context: ModelContext, restaurantId: UUID) {
        guard let pendingId = recordIdPendingComplete else { return }
        guard let record = fetchRecord(id: pendingId, restaurantId: restaurantId, context: context),
              record.isActive else {
            recordIdPendingComplete = nil
            return
        }
    }
}
