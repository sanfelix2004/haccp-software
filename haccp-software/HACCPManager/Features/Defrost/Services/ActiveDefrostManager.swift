//
//  ActiveDefrostManager.swift
//  Stato globale decongelamenti in corso (overlay). Nessun tick @Published:
//  i cronometri UI usano LiveProcessDurationText / TimelineView.
//

import Foundation
import SwiftData
import Combine

struct ActiveDefrostSnapshot: Identifiable, Equatable {
    let id: UUID
    let productName: String
    let methodLabel: String
    let lotNumber: String?
    let startAt: Date
    let operatorName: String

    init(record: DefrostRecord) {
        id = record.id
        productName = record.productName
        methodLabel = record.method
        lotNumber = record.lotNumber
        startAt = record.startAt
        operatorName = record.createdByNameSnapshot
    }
}

@MainActor
final class ActiveDefrostManager: ObservableObject {

    static let shared = ActiveDefrostManager()

    private static let maxActiveFetch = 32

    @Published private(set) var activeSnapshots: [ActiveDefrostSnapshot] = []
    @Published var showActiveListSheet = false
    @Published var recordIdPendingComplete: UUID?
    @Published var errorMessage: String?

    private let service = DefrostService()

    private init() {}

    var hasActiveDefrosts: Bool { !activeSnapshots.isEmpty }

    var primarySnapshot: ActiveDefrostSnapshot? { activeSnapshots.first }

    var collapsedTitle: String {
        switch activeSnapshots.count {
        case 0: return ""
        case 1: return "Decongelamento"
        default: return "\(activeSnapshots.count) decongelamenti attivi"
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
            // Evita di azzerare la bubble su errori SwiftData transitori.
            return
        }
        applyActiveRecords(records)
        reconcilePendingComplete(context: context, restaurantId: restaurantId)
    }

    func fetchRecord(id: UUID, restaurantId: UUID, context: ModelContext) -> DefrostRecord? {
        let rid = restaurantId
        let targetId = id
        var descriptor = FetchDescriptor<DefrostRecord>(
            predicate: #Predicate { $0.id == targetId && $0.restaurantId == rid }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func fetchCriticalities(recordId: UUID, restaurantId: UUID, context: ModelContext) -> [DefrostCriticality] {
        let rid = restaurantId
        let targetRecordId = recordId
        var descriptor = FetchDescriptor<DefrostCriticality>(
            predicate: #Predicate {
                $0.restaurantId == rid && $0.recordId == targetRecordId
            }
        )
        descriptor.fetchLimit = 8
        return (try? context.fetch(descriptor)) ?? []
    }

    func cancel(record: DefrostRecord, context: ModelContext) {
        do {
            try service.cancelDefrost(record, modelContext: context)
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
    ) -> [DefrostRecord]? {
        let rid = restaurantId
        let inProgressStatus = DefrostStatus.inProgress.rawValue
        let delayedStatus = DefrostStatus.delayed.rawValue

        var descriptor = FetchDescriptor<DefrostRecord>(
            predicate: #Predicate { record in
                record.restaurantId == rid
                    && !record.isArchived
                    && record.endAt == nil
                    && (record.statusRaw == inProgressStatus || record.statusRaw == delayedStatus)
            },
            sortBy: [SortDescriptor(\DefrostRecord.startAt)]
        )
        descriptor.fetchLimit = Self.maxActiveFetch

        do {
            let fetched = try context.fetch(descriptor)
            if shouldRefreshDelayedStatuses(fetched) {
                let statusChanged = service.refreshDelayedStatusesIfNeeded(
                    records: fetched,
                    settings: SettingsStorageService.shared.haccp
                )
                if statusChanged {
                    try? context.save()
                }
            }
            return fetched.filter(\.isActive)
        } catch {
            return nil
        }
    }

    /// Salta il loop di ricalcolo se nessun record può ancora diventare "ritardato".
    private func shouldRefreshDelayedStatuses(_ records: [DefrostRecord]) -> Bool {
        if records.contains(where: { $0.isActive && $0.expectedEndAt == nil }) {
            return true
        }
        let now = Date()
        return records.contains { record in
            guard record.endAt == nil, let expected = record.expectedEndAt else { return false }
            return now > expected && record.statusRaw != DefrostStatus.delayed.rawValue
        }
    }

    private func applyActiveRecords(_ records: [DefrostRecord]) {
        let newSnapshots = records.map(ActiveDefrostSnapshot.init(record:))
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

    /// Chiude sheet di completamento se il record non è più valido (cambio ristorante, annullamento, chiusura altrove).
    private func reconcilePendingComplete(context: ModelContext, restaurantId: UUID) {
        guard let pendingId = recordIdPendingComplete else { return }
        guard let record = fetchRecord(id: pendingId, restaurantId: restaurantId, context: context),
              record.isActive else {
            recordIdPendingComplete = nil
            return
        }
    }
}
