//
//  ActiveBlastChillingManager.swift
//  Stato globale abbattimenti in corso + tick UI (solo overlay).
//

import Foundation
import SwiftData
import Combine

struct ActiveBlastSnapshot: Identifiable, Equatable {
    let id: UUID
    let productionId: UUID
    let productionName: String
    let categoryName: String
    let startedAt: Date
    let initialTemperature: Double
    let targetTemperature: Double
    let operatorName: String

    func elapsed(at now: Date) -> TimeInterval {
        BlastChillingDurationFormatter.elapsed(since: startedAt, now: now)
    }

    func formattedElapsed(at now: Date) -> String {
        BlastChillingDurationFormatter.format(since: startedAt, now: now)
    }

    func isOverRecommended(at now: Date) -> Bool {
        BlastChillingDurationFormatter.isOverRecommendedDuration(since: startedAt, now: now)
    }
}

@MainActor
final class ActiveBlastChillingManager: ObservableObject {

    static let shared = ActiveBlastChillingManager()

    @Published private(set) var activeSnapshots: [ActiveBlastSnapshot] = []
    @Published private(set) var now: Date = Date()
    @Published var showActiveListSheet = false
    @Published var recordIdPendingComplete: UUID?
    @Published var errorMessage: String?

    private var tickCancellable: AnyCancellable?
    private let service = BlastChillingService()

    private init() {}

    var hasActiveBlasts: Bool { !activeSnapshots.isEmpty }

    var primarySnapshot: ActiveBlastSnapshot? {
        activeSnapshots.min(by: { $0.startedAt < $1.startedAt })
    }

    var collapsedTitle: String {
        guard let primary = primarySnapshot else { return "" }
        if activeSnapshots.count == 1 {
            return "Abbattimento \(primary.formattedElapsed(at: now))"
        }
        return "\(activeSnapshots.count) abbattimenti attivi"
    }

    var collapsedSubtitle: String {
        "Tocca per terminare"
    }

    var showsOverRecommendedWarning: Bool {
        activeSnapshots.contains { $0.isOverRecommended(at: now) }
    }

    func reset() {
        activeSnapshots = []
        showActiveListSheet = false
        recordIdPendingComplete = nil
        errorMessage = nil
        KitchenProcessTimerTicker.stop(&tickCancellable)
    }

    func refresh(context: ModelContext, restaurantId: UUID?) {
        guard let restaurantId else {
            activeSnapshots = []
            showActiveListSheet = false
            KitchenProcessTimerTicker.stop(&tickCancellable)
            return
        }

        let rid = restaurantId
        let inCorsoStatus = BlastChillingStatus.inCorso.rawValue
        var descriptor = FetchDescriptor<BlastChillingRecord>(
            predicate: #Predicate {
                $0.restaurantId == rid && $0.statusRaw == inCorsoStatus
            },
            sortBy: [SortDescriptor(\BlastChillingRecord.startedAt)]
        )
        descriptor.fetchLimit = 32

        let records = (try? context.fetch(descriptor)) ?? []
        activeSnapshots = records.map {
            ActiveBlastSnapshot(
                id: $0.id,
                productionId: $0.productionId,
                productionName: $0.productionNameSnapshot,
                categoryName: $0.productionCategorySnapshot,
                startedAt: $0.startedAt,
                initialTemperature: $0.initialTemperature,
                targetTemperature: $0.targetTemperature,
                operatorName: $0.createdByNameSnapshot
            )
        }

        if activeSnapshots.isEmpty {
            showActiveListSheet = false
            KitchenProcessTimerTicker.stop(&tickCancellable)
        } else {
            KitchenProcessTimerTicker.start(&tickCancellable) { [weak self] date in
                self?.now = date
            }
        }
    }

    func fetchRecord(id: UUID, context: ModelContext) -> BlastChillingRecord? {
        var descriptor = FetchDescriptor<BlastChillingRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func production(for record: BlastChillingRecord) -> Production {
        Production(
            id: record.productionId,
            restaurantId: record.restaurantId,
            name: record.productionNameSnapshot,
            categoryId: record.productionId,
            categoryNameSnapshot: record.productionCategorySnapshot,
            isCustom: true
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
            refresh(context: context, restaurantId: record.restaurantId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
