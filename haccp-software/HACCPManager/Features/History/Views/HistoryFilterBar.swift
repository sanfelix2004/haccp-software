import SwiftUI

struct HistoryFilterBar: View {
    @Binding var filter: HistoryFilter
    let entries: [HistoryEntry]

    private var statusOptions: [String] {
        ["Tutti"] + Array(Set(entries.map(\.status))).sorted()
    }

    private var operatorOptions: [String] {
        ["Tutti"] + Array(Set(entries.map(\.operatorName))).sorted()
    }

    private var categoryOptions: [String] {
        ["Tutte"] + Array(Set(entries.map(\.category))).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                DatePicker("Dal", selection: $filter.startDate, displayedComponents: .date)
                DatePicker("Al", selection: $filter.endDate, displayedComponents: .date)
                TextField("Cerca", text: $filter.searchText)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 10) {
                Picker("Stato", selection: $filter.status) {
                    ForEach(statusOptions, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)

                Picker("Operatore", selection: $filter.operatorName) {
                    ForEach(operatorOptions, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)

                Picker("Categoria", selection: $filter.category) {
                    ForEach(categoryOptions, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
            }
        }
        .foregroundColor(.white)
    }
}
