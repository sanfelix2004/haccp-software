//
//  ChecklistFilterBar.swift
//

import SwiftUI

struct ChecklistFilterBar: View {
    @Binding var categoryFilter: ChecklistCategory?
    @Binding var frequencyFilter: ChecklistFrequency?

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    HistoryFilterChip(title: "Tutte le categorie", isSelected: categoryFilter == nil) {
                        categoryFilter = nil
                    }
                    ForEach(ChecklistCategory.allCases, id: \.self) { category in
                        HistoryFilterChip(title: category.label, isSelected: categoryFilter == category) {
                            categoryFilter = category
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    HistoryFilterChip(title: "Tutte le frequenze", isSelected: frequencyFilter == nil) {
                        frequencyFilter = nil
                    }
                    ForEach(ChecklistFrequency.allCases, id: \.self) { frequency in
                        HistoryFilterChip(title: frequency.label, isSelected: frequencyFilter == frequency) {
                            frequencyFilter = frequency
                        }
                    }
                }
            }
        }
    }
}
