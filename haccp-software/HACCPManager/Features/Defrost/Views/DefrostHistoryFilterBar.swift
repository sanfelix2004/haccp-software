//
//  DefrostHistoryFilterBar.swift
//

import SwiftUI

struct DefrostHistoryFilterBar: View {
    @Binding var filter: DefrostFilter
    let records: [DefrostRecord]

    @Environment(\.theme) private var theme

    private var statusOptions: [String] {
        ["Tutti"] + DefrostStatus.allCases.map(\.label)
    }

    private var methodOptions: [String] {
        ["Tutti"] + Array(Set(records.map(\.method))).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                DatePicker("Dal", selection: $filter.startDate, displayedComponents: .date)
                DatePicker("Al", selection: $filter.endDate, displayedComponents: .date)
            }
            TextField("Cerca prodotto o lotto…", text: $filter.searchText)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 10) {
                Picker("Stato", selection: $filter.status) {
                    ForEach(statusOptions, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                Picker("Metodo", selection: $filter.method) {
                    ForEach(methodOptions, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
            }
        }
        .foregroundStyle(theme.colorTextPrimary)
    }
}
