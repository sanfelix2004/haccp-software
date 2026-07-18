import Foundation

enum HistoryLotSearchMode: String, CaseIterable, Identifiable {
    case all = "Tutti i lotti"
    case internalLot = "Lotto produzione"
    case supplierLot = "Lotto fornitore"

    var id: String { rawValue }
}

struct HistoryFilter: Equatable {
    var searchText: String = ""
    var lotSearchMode: HistoryLotSearchMode = .all
    var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var endDate: Date = Date()
    var status: String = "Tutti"
    var operatorName: String = "Tutti"
    var category: String = "Tutte"
}
