import Foundation
import Combine

@MainActor
final class HistoryViewModel: ObservableObject {
    let service = HistoryService()
}

@MainActor
final class HistoryModuleDetailViewModel: ObservableObject {
    @Published var filter = HistoryFilter() {
        didSet { scheduleFilterApply() }
    }
    @Published private(set) var appliedFilter = HistoryFilter()

    private var debounceTask: Task<Void, Never>?

    func filtered(entries: [HistoryEntry]) -> [HistoryEntry] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: appliedFilter.startDate)
        let endStart = calendar.startOfDay(for: appliedFilter.endDate)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: endStart) ?? appliedFilter.endDate
        return entries.filter { entry in
            let categoryOk = appliedFilter.category == "Tutte" || entry.category == appliedFilter.category
            let statusOk = appliedFilter.status == "Tutti" || entry.status == appliedFilter.status
            let operatorOk = appliedFilter.operatorName == "Tutti" || entry.operatorName == appliedFilter.operatorName
            let periodOk = entry.date >= start && entry.date <= end
            let search = appliedFilter.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchOk = search.isEmpty
                || entry.searchText.localizedCaseInsensitiveContains(search)
            return categoryOk && statusOk && operatorOk && periodOk && searchOk
        }
    }

    private func scheduleFilterApply() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: PerformanceConfig.filterDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            appliedFilter = filter
        }
    }

    deinit {
        debounceTask?.cancel()
    }
}
