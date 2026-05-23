//
//  ProductionLabelsViewModel.swift
//

import Foundation
import Combine

@MainActor
final class ProductionLabelsViewModel: ObservableObject {
    let service = ProductionLabelsService()

    @Published var filter = ProductionLabelFilter() {
        didSet { scheduleFilterApply() }
    }
    @Published private(set) var appliedFilter = ProductionLabelFilter()
    @Published var selectedLabelId: UUID?

    private var debounceTask: Task<Void, Never>?

    func filteredLabels(from labels: [ProductionLabelRecord]) -> [ProductionLabelRecord] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: appliedFilter.startDate)
        let endStart = calendar.startOfDay(for: appliedFilter.endDate)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: endStart) ?? appliedFilter.endDate

        return labels.filter { label in
            if appliedFilter.showArchived {
                guard label.isArchived else { return false }
            } else if label.isArchived {
                return false
            }

            let search = appliedFilter.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchOk = search.isEmpty
                || label.productName.localizedCaseInsensitiveContains(search)
                || (label.lotCode?.localizedCaseInsensitiveContains(search) ?? false)
                || (label.supplier?.localizedCaseInsensitiveContains(search) ?? false)

            let statusOk = appliedFilter.status == "Tutti" || label.labelStatus.label == appliedFilter.status
            let categoryOk = appliedFilter.category == "Tutte" || (label.category ?? "—") == appliedFilter.category
            let operatorOk = appliedFilter.operatorName == "Tutti" || label.createdByNameSnapshot == appliedFilter.operatorName
            let sourceOk = appliedFilter.source == "Tutte" || label.sourceModule.label == appliedFilter.source
            let periodOk = label.createdAt >= start && label.createdAt <= end

            return searchOk && statusOk && categoryOk && operatorOk && sourceOk && periodOk
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    func stats(from labels: [ProductionLabelRecord]) -> (today: Int, expiringSoon: Int, active: Int) {
        let calendar = Calendar.current
        let today = labels.filter { calendar.isDateInToday($0.createdAt) }.count
        let soon = labels.filter { $0.expiryState == .soon && !$0.isArchived }.count
        let active = labels.filter { !$0.isArchived && $0.labelStatus == .active }.count
        return (today, soon, active)
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
