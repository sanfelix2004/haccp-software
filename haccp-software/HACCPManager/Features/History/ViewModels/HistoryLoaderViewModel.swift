//
//  HistoryLoaderViewModel.swift
//  Caricamento storico asincrono con fetch limitati.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class HistoryLoaderViewModel: ObservableObject {
    @Published private(set) var entries: [HistoryEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadToken = UUID()

    private let service = HistoryService()
    private var loadTask: Task<Void, Never>?

    func reload(context: ModelContext, restaurantId: UUID?) {
        loadTask?.cancel()
        guard let restaurantId else {
            entries = []
            isLoading = false
            return
        }

        isLoading = true
        let token = UUID()
        loadToken = token

        loadTask = Task {
            let data = HistoryDataFetcher.fetch(context: context, restaurantId: restaurantId)
            guard !Task.isCancelled else { return }

            let built = service.buildEntries(
                restaurantId: restaurantId,
                temperatureRecords: data.temperatureRecords,
                fridgeRecords: data.fridgeRecords,
                checklistRuns: data.checklistRuns,
                checklistItemResults: data.checklistItemResults,
                checklistAuditLogs: data.checklistAuditLogs,
                cleaningRecords: data.cleaningRecords,
                defrostRecords: data.defrostRecords,
                blastRecords: data.blastRecords,
                labelRecords: data.labelRecords,
                goodsRecords: data.goodsRecords,
                traceabilityRecords: data.traceabilityRecords,
                traceabilityLogs: data.traceabilityLogs,
                oilRecords: data.oilRecords
            )

            guard !Task.isCancelled, loadToken == token else { return }
            entries = built
            isLoading = false
        }
    }

    deinit {
        loadTask?.cancel()
    }
}
