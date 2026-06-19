//
//  ProductionLabelFilterBar.swift
//

import SwiftUI

struct ProductionLabelFilterBar: View {
    @Binding var filter: ProductionLabelFilter
    let labels: [ProductionLabelRecord]

    @Environment(\.theme) private var theme

    private var statusOptions: [String] {
        ["Tutti"] + ProductionLabelStatus.allCases.map(\.label)
    }

    private var categoryOptions: [String] {
        ["Tutte"] + Array(Set(labels.compactMap(\.category).filter { !$0.isEmpty })).sorted()
    }

    private var operatorOptions: [String] {
        ["Tutti"] + Array(Set(labels.map(\.createdByNameSnapshot))).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                DatePicker("Dal", selection: $filter.startDate, displayedComponents: .date)
                DatePicker("Al", selection: $filter.endDate, displayedComponents: .date)
            }
            TextField("Cerca prodotto, lotto, fornitore…", text: $filter.searchText)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                filterPicker("Stato", selection: $filter.status, options: statusOptions)
                filterPicker("Categoria", selection: $filter.category, options: categoryOptions)
            }
            HStack(spacing: 10) {
                filterPicker("Operatore", selection: $filter.operatorName, options: operatorOptions)
            }

            Toggle("Mostra archivio", isOn: $filter.showArchived)
                .font(theme.typography.subheadline)
        }
        .foregroundStyle(theme.colorTextPrimary)
    }

    private func filterPicker(_ title: String, selection: Binding<String>, options: [String]) -> some View {
        Picker(title, selection: selection) {
            ForEach(options, id: \.self) { Text($0).tag($0) }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
