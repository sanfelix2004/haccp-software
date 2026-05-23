//
//  DefrostViewModel.swift
//

import Foundation
import Combine

@MainActor
final class DefrostViewModel: ObservableObject {
    let service = DefrostService()

    @Published var historyFilter = DefrostFilter() {
        didSet { scheduleFilterApply() }
    }
    @Published private(set) var appliedHistoryFilter = DefrostFilter()

    private var debounceTask: Task<Void, Never>?

    func activeRecords(from records: [DefrostRecord]) -> [DefrostRecord] {
        records.filter(\.isActive).sorted { $0.startAt > $1.startAt }
    }

    func completedToday(from records: [DefrostRecord]) -> [DefrostRecord] {
        let calendar = Calendar.current
        return records.filter {
            guard let end = $0.endAt else { return false }
            return calendar.isDateInToday(end)
        }
    }

    func historyRecords(from records: [DefrostRecord]) -> [DefrostRecord] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: appliedHistoryFilter.startDate)
        let endStart = calendar.startOfDay(for: appliedHistoryFilter.endDate)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: endStart) ?? appliedHistoryFilter.endDate

        return records.filter { record in
            guard !record.isActive else { return false }
            let search = appliedHistoryFilter.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchOk = search.isEmpty
                || record.productName.localizedCaseInsensitiveContains(search)
                || (record.lotNumber?.localizedCaseInsensitiveContains(search) ?? false)
            let statusOk = appliedHistoryFilter.status == "Tutti"
                || record.historyStatusLabel == appliedHistoryFilter.status
            let methodOk = appliedHistoryFilter.method == "Tutti"
                || record.method == appliedHistoryFilter.method
            let anchor = record.historyAnchorDate
            let periodOk = anchor >= start && anchor <= end
            return searchOk && statusOk && methodOk && periodOk
        }
        .sorted { ($0.endAt ?? $0.startAt) > ($1.endAt ?? $1.startAt) }
    }

    func stats(from records: [DefrostRecord]) -> (inProgress: Int, completedToday: Int) {
        (
            activeRecords(from: records).count,
            completedToday(from: records).count
        )
    }

    private func scheduleFilterApply() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: PerformanceConfig.filterDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            appliedHistoryFilter = historyFilter
        }
    }

    deinit {
        debounceTask?.cancel()
    }
}
