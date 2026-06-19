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

    private var debounceTask: Task<Void, Never>?

    func filteredLabels(
        from labels: [ProductionLabelRecord],
        source: ProductionLabelSource? = nil,
        linkedSource: ProductionLabelLinkedSource? = nil
    ) -> [ProductionLabelRecord] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: appliedFilter.startDate)
        let endStart = calendar.startOfDay(for: appliedFilter.endDate)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: endStart) ?? appliedFilter.endDate

        return labels.filter { label in
            let archiveOk = appliedFilter.showArchived || !label.isArchived
            let sourceOk: Bool = {
                if let linkedSource {
                    return ProductionLabelLinkMatcher.matchesLinkedSource(label, linkedSource)
                }
                if let source {
                    return label.sourceModule == source
                }
                return true
            }()

            let search = appliedFilter.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchOk = search.isEmpty
                || label.productName.localizedCaseInsensitiveContains(search)
                || (label.lotCode?.localizedCaseInsensitiveContains(search) ?? false)
                || (label.supplier?.localizedCaseInsensitiveContains(search) ?? false)

            let statusOk = appliedFilter.status == "Tutti" || label.labelStatus.label == appliedFilter.status
            let categoryOk = appliedFilter.category == "Tutte" || (label.category ?? "—") == appliedFilter.category
            let operatorOk = appliedFilter.operatorName == "Tutti" || label.createdByNameSnapshot == appliedFilter.operatorName
            let periodOk = label.createdAt >= start && label.createdAt <= end

            return archiveOk && sourceOk && searchOk && statusOk && categoryOk && operatorOk && periodOk
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    func labelCount(from labels: [ProductionLabelRecord], source: ProductionLabelLinkedSource) -> Int {
        filteredLabels(from: labels, linkedSource: source).count
    }

    func pendingSourceCount(
        for source: ProductionLabelLinkedSource,
        dataStore: ProductionLabelsDataStore,
        labels: [ProductionLabelRecord]
    ) -> Int {
        ProductionLabelLinkMatcher.pendingCount(for: source, dataStore: dataStore, labels: labels)
    }

    func stats(from labels: [ProductionLabelRecord]) -> (today: Int, expiringSoon: Int, active: Int) {
        let calendar = Calendar.current
        let visible = labels.filter { !$0.isArchived }
        let today = visible.filter { calendar.isDateInToday($0.createdAt) }.count
        let soon = visible.filter { $0.expiryState == .soon }.count
        let active = visible.filter { $0.labelStatus == .active }.count
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
