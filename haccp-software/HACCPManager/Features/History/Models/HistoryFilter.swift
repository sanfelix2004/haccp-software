import Foundation

struct HistoryFilter {
    var searchText: String = ""
    var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var endDate: Date = Date()
    var status: String = "Tutti"
    var operatorName: String = "Tutti"
    var category: String = "Tutte"
}
