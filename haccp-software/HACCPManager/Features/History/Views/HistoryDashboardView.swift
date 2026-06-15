import SwiftUI

struct HistoryDashboardView: View {
    let entries: [HistoryEntry]

    @Environment(\.theme) private var theme
    @State private var searchText = ""
    @State private var showOnlyActive = false

    private var entriesByModule: [HistoryModule: [HistoryEntry]] {
        Dictionary(grouping: entries, by: \.module)
    }

    private var totalCount: Int { entries.count }

    private var criticalCount: Int { entries.filter(\.hasCriticality).count }

    private var todayCount: Int {
        entries.filter { Calendar.current.isDateInToday($0.date) }.count
    }

    private var recentEntries: [HistoryEntry] {
        entries.sorted { $0.date > $1.date }.prefix(6).map { $0 }
    }

    private var visibleModules: [HistoryModule] {
        HistoryModule.dashboardModules.filter { module in
            let moduleEntries = entriesByModule[module] ?? []
            if showOnlyActive && moduleEntries.isEmpty { return false }
            guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
            let query = searchText.lowercased()
            if module.rawValue.lowercased().contains(query) { return true }
            if module.shortTitle.lowercased().contains(query) { return true }
            return moduleEntries.contains { $0.searchText.lowercased().contains(query) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.sectionSpacing) {
                heroHeader
                statsRow
                searchBar
                if !recentEntries.isEmpty {
                    recentActivitySection
                }
                modulesSection
            }
            .padding(theme.spacing.screenPadding + 8)
        }
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle("Storia")
        .navigationBarTitleDisplayMode(.large)
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.colorPrimary)
                Text("Archivio HACCP")
                    .font(theme.typography.title2.weight(.bold))
                    .foregroundStyle(theme.colorTextPrimary)
            }
            Text("Tutte le registrazioni del ristorante, organizzate per modulo e data.")
                .font(theme.typography.subheadline)
                .foregroundStyle(theme.colorTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statsRow: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            HistoryStatPill(title: "Registrazioni", value: "\(totalCount)", icon: "doc.text.fill")
            HistoryStatPill(
                title: "Oggi",
                value: "\(todayCount)",
                icon: "sun.max.fill",
                tint: theme.colorSuccess
            )
            HistoryStatPill(
                title: "Criticità",
                value: "\(criticalCount)",
                icon: "exclamationmark.triangle.fill",
                tint: criticalCount > 0 ? theme.colorError : theme.colorTextSecondary
            )
            HistoryStatPill(
                title: "Moduli attivi",
                value: "\(entriesByModule.keys.count)",
                icon: "square.grid.2x2.fill",
                tint: theme.colorInfo
            )
        }
    }

    private var searchBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.colorTextSecondary)
                TextField("Cerca modulo o registrazione…", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.colorTextSecondary)
                    }
                }
            }
            .padding(12)
            .background(theme.colorSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))

            Toggle("Mostra solo moduli con dati", isOn: $showOnlyActive)
                .font(theme.typography.subheadline)
                .tint(theme.colorPrimary)
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Attività recente")
                .font(theme.typography.headline)
                .foregroundStyle(theme.colorTextPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentEntries) { entry in
                        NavigationLink {
                            HistoryModuleDetailView(
                                module: entry.module,
                                entries: entriesByModule[entry.module] ?? []
                            )
                        } label: {
                            HistoryRecentChip(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var modulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Moduli")
                .font(theme.typography.headline)
                .foregroundStyle(theme.colorTextPrimary)

            if visibleModules.isEmpty {
                DashboardEmptyStateView(state: .init(
                    title: "Nessun risultato",
                    message: "Prova a cambiare ricerca o disattiva il filtro sui moduli attivi.",
                    actionTitle: nil
                ))
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 160), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(visibleModules) { module in
                        let moduleEntries = entriesByModule[module] ?? []
                        NavigationLink {
                            HistoryModuleDetailView(module: module, entries: moduleEntries)
                        } label: {
                            HistoryModuleCard(module: module, entries: moduleEntries)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct HistoryRecentChip: View {
    let entry: HistoryEntry

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: entry.module.icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(entry.module.accentColor(theme: theme))
                Spacer()
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .font(theme.typography.caption2)
                    .foregroundStyle(theme.colorTextSecondary)
            }
            Text(entry.title)
                .font(theme.typography.subheadline.weight(.semibold))
                .foregroundStyle(theme.colorTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(entry.module.shortTitle)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
        }
        .frame(width: 168, alignment: .leading)
        .padding(12)
        .background(theme.colorSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .strokeBorder(theme.colorDivider.opacity(0.6), lineWidth: 1)
        )
    }
}
