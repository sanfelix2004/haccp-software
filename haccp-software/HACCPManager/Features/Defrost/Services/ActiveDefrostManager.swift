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

    @Published private(set) var activeSnapshots: [ActiveDefrostSnapshot] = []
    @Published private(set) var now: Date = Date()
    @Published var showActiveListSheet = false
    @Published var recordIdPendingComplete: UUID?
    @Published var errorMessage: String?

    private var tickCancellable: AnyCancellable?

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
        activeSnapshots = []
        showActiveListSheet = false
        recordIdPendingComplete = nil
        errorMessage = nil
        stopTicking()
    }

    func refresh(context: ModelContext, restaurantId: UUID?) {
        guard let restaurantId else {
            activeSnapshots = []
            stopTicking()
            return
        }

        let rid = restaurantId
        var descriptor = FetchDescriptor<DefrostRecord>(
            predicate: #Predicate { $0.restaurantId == rid && $0.endAt == nil },
            sortBy: [SortDescriptor(\DefrostRecord.startAt)]
        )
        descriptor.fetchLimit = 32

        let cancelledStatus = DefrostStatus.cancelled.rawValue
        let records = ((try? context.fetch(descriptor)) ?? []).filter {
            $0.endAt == nil && $0.statusRaw != cancelledStatus
        }

        activeSnapshots = records.map {
            ActiveDefrostSnapshot(
                id: $0.id,
                productName: $0.productName,
                methodLabel: $0.method,
                lotNumber: $0.lotNumber,
                startAt: $0.startAt,
                operatorName: $0.createdByNameSnapshot
            )
        }

        if activeSnapshots.isEmpty {
            showActiveListSheet = false
            stopTicking()
        } else {
            startTicking()
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
            try DefrostService().cancelDefrost(record, modelContext: context)
            refresh(context: context, restaurantId: record.restaurantId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startTicking() {
        guard tickCancellable == nil else { return }
        tickCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.now = date
            }
    }

    private func stopTicking() {
        tickCancellable?.cancel()
        tickCancellable = nil
    }
}
