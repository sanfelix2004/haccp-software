import Foundation

struct HistoryEntryDetail: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

struct HistoryEntry: Identifiable {
    let id: String
    let module: HistoryModule
    let title: String
    let category: String
    let status: String
    let operatorName: String
    let date: Date
    let details: [HistoryEntryDetail]
    let hasCriticality: Bool

    var searchText: String {
        ([module.rawValue, title, category, status, operatorName] + details.flatMap { [$0.label, $0.value] })
            .joined(separator: " ")
    }
}
