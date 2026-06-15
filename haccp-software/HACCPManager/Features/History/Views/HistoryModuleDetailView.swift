import SwiftUI

struct HistoryModuleDetailView: View {
    let module: HistoryModule
    let entries: [HistoryEntry]

    @Environment(\.theme) private var theme
    @StateObject private var vm = HistoryModuleDetailViewModel()
    @State private var visibleCount = PerformanceConfig.historyPageSize

    private var filteredEntries: [HistoryEntry] {
        vm.filtered(entries: entries).sorted { $0.date > $1.date }
    }

    private var visibleEntries: [HistoryEntry] {
        Array(filteredEntries.prefix(visibleCount))
    }

    private var groupedEntries: [(date: Date, entries: [HistoryEntry])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: visibleEntries) { calendar.startOfDay(for: $0.date) }
        return groups
            .map { (date: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    private var hasMore: Bool {
        visibleCount < filteredEntries.count
    }

    private var criticalCount: Int {
        filteredEntries.filter(\.hasCriticality).count
    }

    private var accent: Color {
        module.accentColor(theme: theme)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacing.sectionSpacing) {
                moduleHeader
                filtersCard

                if filteredEntries.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessuna registrazione",
                        message: "Non ci sono dati per questo modulo nel periodo o con i filtri selezionati.",
                        actionTitle: nil
                    ))
                    .padding(.vertical, 24)
                } else {
                    timelineContent
                    if hasMore {
                        loadMoreButton
                    }
                }
            }
            .padding(theme.spacing.screenPadding + 8)
        }
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle(module.shortTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: vm.appliedFilter) { _, _ in
            visibleCount = PerformanceConfig.historyPageSize
        }
    }

    private var moduleHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.16))
                    .frame(width: 52, height: 52)
                Image(systemName: module.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(module.rawValue)
                    .font(theme.typography.title3.weight(.bold))
                    .foregroundStyle(theme.colorTextPrimary)
                Text("\(filteredEntries.count) registrazioni nel periodo")
                    .font(theme.typography.subheadline)
                    .foregroundStyle(theme.colorTextSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .fill(theme.colorSurfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .strokeBorder(accent.opacity(0.3), lineWidth: 1)
        )
    }

    private var filtersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                HistoryMiniStat(label: "Totale", value: "\(filteredEntries.count)")
                HistoryMiniStat(label: "Criticità", value: "\(criticalCount)", highlight: criticalCount > 0)
                HistoryMiniStat(
                    label: "Operatori",
                    value: "\(Set(filteredEntries.map(\.operatorName)).count)"
                )
            }
            HistoryFilterBar(filter: $vm.filter, entries: entries)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .fill(theme.colorSurfaceElevated)
        )
    }

    private var timelineContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Timeline")
                .font(theme.typography.headline)
                .foregroundStyle(theme.colorTextPrimary)

            ForEach(groupedEntries, id: \.date) { group in
                HistoryDateSection(date: group.date, entries: group.entries)
            }
        }
    }

    private var loadMoreButton: some View {
        Button {
            visibleCount += PerformanceConfig.historyPageSize
        } label: {
            Label(
                "Carica altre \(min(PerformanceConfig.historyPageSize, filteredEntries.count - visibleCount))",
                systemImage: "arrow.down.circle.fill"
            )
            .font(theme.typography.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(PremiumPressButtonStyle())
    }
}

private struct HistoryMiniStat: View {
    let label: String
    let value: String
    var highlight: Bool = false

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(theme.typography.headline.weight(.bold))
                .foregroundStyle(highlight ? theme.colorError : theme.colorTextPrimary)
            Text(label)
                .font(theme.typography.caption2)
                .foregroundStyle(theme.colorTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
