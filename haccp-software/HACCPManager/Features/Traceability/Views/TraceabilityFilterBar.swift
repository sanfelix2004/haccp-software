//
//  TraceabilityFilterBar.swift
//

import SwiftUI

struct TraceabilityFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedStatus: ProductStatus?
    @Binding var selectedDateFilter: TraceabilityView.DateFilter

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.colorTextSecondary)
                TextField("Cerca prodotto, lotto, fornitore…", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.colorTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(theme.colorSurface)
            .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    HistoryFilterChip(title: "Tutti gli stati", isSelected: selectedStatus == nil) {
                        selectedStatus = nil
                    }
                    ForEach(ProductStatus.allCases, id: \.rawValue) { status in
                        HistoryFilterChip(title: status.label, isSelected: selectedStatus == status) {
                            selectedStatus = status
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TraceabilityView.DateFilter.allCases) { filter in
                        HistoryFilterChip(title: filter.rawValue, isSelected: selectedDateFilter == filter) {
                            selectedDateFilter = filter
                        }
                    }
                }
            }
        }
    }
}
