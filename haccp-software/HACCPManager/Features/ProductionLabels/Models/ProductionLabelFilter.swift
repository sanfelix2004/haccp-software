//
//  ProductionLabelFilter.swift
//

import Foundation

struct ProductionLabelFilter: Equatable {
    var searchText: String = ""
    var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var endDate: Date = Date()
    var status: String = "Tutti"
    var category: String = "Tutte"
    var operatorName: String = "Tutti"
    var source: String = "Tutte"
    var showArchived: Bool = false
}
