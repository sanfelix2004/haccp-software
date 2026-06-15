import SwiftUI

struct HistoryFilterBar: View {
    @Binding var filter: HistoryFilter
    let entries: [HistoryEntry]

    @Environment(\.theme) private var theme
    @State private var showAdvanced = false

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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.colorTextSecondary)
                TextField("Cerca titolo, operatore, dettagli…", text: $filter.searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(12)
            .background(theme.colorSurface)
            .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HistoryPeriodPreset.allCases) { preset in
                        HistoryFilterChip(
                            title: preset.rawValue,
                            isSelected: preset.contains(filter: filter)
                        ) {
                            preset.apply(to: &filter)
                        }
                    }
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAdvanced.toggle()
                }
            } label: {
                HStack {
                    Label(showAdvanced ? "Nascondi filtri" : "Altri filtri", systemImage: "line.3.horizontal.decrease.circle")
                        .font(theme.typography.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(theme.colorPrimary)
            }

            if showAdvanced {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dal")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary)
                            DatePicker("", selection: $filter.startDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Al")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary)
                            DatePicker("", selection: $filter.endDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }

                    filterMenu(title: "Stato", selection: $filter.status, options: statusOptions)
                    filterMenu(title: "Operatore", selection: $filter.operatorName, options: operatorOptions)
                    filterMenu(title: "Categoria", selection: $filter.category, options: categoryOptions)

                    Button("Reimposta filtri") {
                        filter = HistoryFilter()
                    }
                    .font(theme.typography.subheadline)
                    .foregroundStyle(theme.colorPrimary)
                }
                .padding(12)
                .background(theme.colorSurface)
                .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
            }
        }
    }

    private func filterMenu(title: String, selection: Binding<String>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

struct HistoryFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(isSelected ? theme.colorTextOnPrimary : theme.colorTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? theme.colorPrimary : theme.colorSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? theme.colorPrimary : theme.colorDivider, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
