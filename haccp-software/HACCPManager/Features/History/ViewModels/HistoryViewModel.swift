import Foundation
import Combine

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var selectedModule: String = "Tutti"
    @Published var selectedCategory: String = "Tutte"
    @Published var selectedMonth: Int?
    @Published var selectedDay: Int?
    @Published var searchText: String = ""

    let service = HistoryService()

    func filtered(entries: [HistoryEntry]) -> [HistoryEntry] {
        entries.filter { entry in
            let moduleOk = selectedModule == "Tutti" || entry.module == selectedModule
            let categoryOk = selectedCategory == "Tutte" || entry.category == selectedCategory
            let monthOk = selectedMonth == nil || Calendar.current.component(.month, from: entry.date) == selectedMonth
            let dayOk = selectedDay == nil || Calendar.current.component(.day, from: entry.date) == selectedDay
            let searchOk = searchText.isEmpty
                || entry.productOrDevice.localizedCaseInsensitiveContains(searchText)
                || entry.operatorName.localizedCaseInsensitiveContains(searchText)
                || entry.title.localizedCaseInsensitiveContains(searchText)
            return moduleOk && categoryOk && monthOk && dayOk && searchOk
        }
    }
}
