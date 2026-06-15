//
//  ActiveDefrostManager.swift
//  Stato globale decongelamenti in corso + tick UI (solo overlay).
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

    func elapsed(at now: Date) -> TimeInterval {
        DefrostDurationFormatter.elapsed(since: startAt, now: now)
    }

    func formattedElapsed(at now: Date) -> String {
        DefrostDurationFormatter.format(since: startAt, now: now)
    }
}

@MainActor
final class ActiveDefrostManager: ObservableObject {

    static let shared = ActiveDefrostManager()

    private static let maxActiveFetch = 32

    @Published private(set) var activeSnapshots: [ActiveDefrostSnapshot] = []
    @Published private(set) var now: Date = Date()
    @Published var showActiveListSheet = false
    @Published var recordIdPendingComplete: UUID?
    @Published var errorMessage: String?

    private var tickCancellable: AnyCancellable?
    private let service = DefrostService()

    private init() {}

    var hasActiveDefrosts: Bool { !activeSnapshots.isEmpty }

    var primarySnapshot: ActiveDefrostSnapshot? {
        activeSnapshots.min(by: { $0.startAt < $1.startAt })
    }

    var collapsedTitle: String {
        guard let primary = primarySnapshot else { return "" }
        if activeSnapshots.count == 1 {
            return "Decongelamento \(primary.formattedElapsed(at: now))"
        }
        return "\(activeSnapshots.count) decongelamenti attivi"
    }

    var collapsedSubtitle: String {
        "Tocca per terminare"
    }

    func reset() {
        clearActiveState()
        recordIdPendingComplete = nil
        errorMessage = nil
    }

    func refresh(context: ModelContext, restaurantId: UUID?) {
        guard let restaurantId else {
            clearActiveState()
            return
        }

        switch fetchActiveRecords(context: context, restaurantId: restaurantId) {
        case .success(let records):
            applyActiveRecords(records)
        case .failure:
            // Evita di azzerare la bubble su errori SwiftData transitori.
            break
        }
    }

    func fetchRecord(id: UUID, context: ModelContext) -> DefrostRecord? {
        var descriptor = FetchDescriptor<DefrostRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func fetchCriticalities(restaurantId: UUID, context: ModelContext) -> [DefrostCriticality] {
        let rid = restaurantId
        var descriptor = FetchDescriptor<DefrostCriticality>(
            predicate: #Predicate { $0.restaurantId == rid }
        )
        descriptor.fetchLimit = 300
        return (try? context.fetch(descriptor)) ?? []
    }

    func cancel(record: DefrostRecord, context: ModelContext) {
        do {
            try service.cancelDefrost(record, modelContext: context)
            refresh(context: context, restaurantId: record.restaurantId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private

    private enum FetchResult {
        case success([DefrostRecord])
        case failure
    }

    private func fetchActiveRecords(
        context: ModelContext,
        restaurantId: UUID
    ) -> FetchResult {
        let rid = restaurantId
        let inProgressStatus = DefrostStatus.inProgress.rawValue
        let delayedStatus = DefrostStatus.delayed.rawValue

        var descriptor = FetchDescriptor<DefrostRecord>(
            predicate: #Predicate { record in
                record.restaurantId == rid
                    && (record.statusRaw == inProgressStatus || record.statusRaw == delayedStatus)
            },
            sortBy: [SortDescriptor(\DefrostRecord.startAt)]
        )
        descriptor.fetchLimit = Self.maxActiveFetch

        do {
            let fetched = try context.fetch(descriptor)
            service.refreshDelayedStatuses(records: fetched)
            if !fetched.isEmpty {
                try? context.save()
            }
            return .success(fetched.filter(\.isActive))
        } catch {
            return .failure
        }
    }

    private func applyActiveRecords(_ records: [DefrostRecord]) {
        activeSnapshots = records.map(ActiveDefrostSnapshot.init(record:))

        if activeSnapshots.isEmpty {
            clearActiveState()
        } else {
            KitchenProcessTimerTicker.start(&tickCancellable) { [weak self] date in
                self?.now = date
            }
        }
    }

    private func clearActiveState() {
        activeSnapshots = []
        showActiveListSheet = false
        KitchenProcessTimerTicker.stop(&tickCancellable)
    }
}
