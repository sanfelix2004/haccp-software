import Foundation
import Combine

@MainActor
final class HistoryViewModel: ObservableObject {
    let service = HistoryService()
}

@MainActor
final class HistoryModuleDetailViewModel: ObservableObject {
    @Published var filter = HistoryFilter()

    func filtered(entries: [HistoryEntry]) -> [HistoryEntry] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: filter.startDate)
        let endStart = calendar.startOfDay(for: filter.endDate)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: endStart) ?? filter.endDate
        return entries.filter { entry in
            let categoryOk = filter.category == "Tutte" || entry.category == filter.category
            let statusOk = filter.status == "Tutti" || entry.status == filter.status
            let operatorOk = filter.operatorName == "Tutti" || entry.operatorName == filter.operatorName
            let periodOk = entry.date >= start && entry.date <= end
            let search = filter.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchOk = search.isEmpty
                || entry.searchText.localizedCaseInsensitiveContains(search)
            return categoryOk && statusOk && operatorOk && periodOk && searchOk
        }
    }
}
