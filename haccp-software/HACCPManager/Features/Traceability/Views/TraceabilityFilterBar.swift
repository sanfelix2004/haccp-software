import SwiftUI
import SwiftData

struct TraceabilityFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedFilter: TraceabilityHubFilter
    var productionSuggestions: [String] = []

    @Environment(\.theme) private var theme
    @FocusState private var isSearchFocused: Bool

    private var activeTokens: [String] {
        TraceabilityArchiveSearch.tokens(from: searchText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.colorTextSecondary)
                TextField("Cerca piatto, alimento, lotto produzione o fornitore…", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
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

            if !activeTokens.isEmpty {
                Text("Filtro attivo: \(activeTokens.joined(separator: " · "))")
                    .font(theme.typography.caption2)
                    .foregroundStyle(theme.colorTextSecondary)
            }

            if searchText.isEmpty, !productionSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(productionSuggestions, id: \.self) { name in
                            Button {
                                searchText = name
                                isSearchFocused = true
                            } label: {
                                Label(name, systemImage: "fork.knife")
                                    .font(theme.typography.caption.weight(.semibold))
                                    .foregroundStyle(theme.colorTextSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(theme.colorSurface)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(theme.colorDivider, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(TraceabilityHubFilter.allCases) { filter in
                    HistoryFilterChip(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
        }
    }
}

/// Statistica tappabile che applica un filtro hub.
struct TraceabilityMetricTile: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let accent: Color
    let isActive: Bool
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                    Spacer()
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(accent)
                    }
                }
                Text(value)
                    .font(theme.typography.title2.bold())
                    .foregroundStyle(theme.colorTextPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(title)
                    .font(theme.typography.caption.weight(.semibold))
                    .foregroundStyle(theme.colorTextPrimary)
                Text(subtitle)
                    .font(theme.typography.caption2)
                    .foregroundStyle(theme.colorTextSecondary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isActive ? accent.opacity(0.12) : theme.colorSurface)
            .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                    .stroke(isActive ? accent.opacity(0.5) : theme.colorDivider.opacity(0.8), lineWidth: isActive ? 1.5 : 1)
            )
        }
        .buttonStyle(PremiumPressButtonStyle())
    }
}

/// Banner sessione camera aperta con lotti da associare.
struct TraceabilityOpenSessionCard: View {
    let session: TraceabilityOpenSession
    let onResume: () -> Void
    let onDismiss: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.colorPrimary.opacity(0.14))
                    .frame(width: 48, height: 48)
                Image(systemName: "camera.fill")
                    .foregroundStyle(theme.colorPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Sessione in corso")
                    .font(theme.typography.subheadline.bold())
                Text("\(session.itemCount) lotti · \(session.previewNames.prefix(2).joined(separator: ", "))\(session.previewNames.count > 2 ? "…" : "")")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button("Riprendi", action: onResume)
                .font(theme.typography.caption.weight(.semibold))
                .buttonStyle(.borderedProminent)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.colorTextSecondary)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(theme.colorPrimary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .stroke(theme.colorPrimary.opacity(0.25), lineWidth: 1)
        )
    }
}
