import SwiftUI

struct HistoryModuleDetailView: View {
    let module: HistoryModule
    let entries: [HistoryEntry]
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

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                DashboardCardView(title: "Storico \(module.rawValue)") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label(module.rawValue, systemImage: module.icon)
                                .font(.title3.bold())
                                .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                            Spacer()
                            Text("\(filteredEntries.count) registrazioni")
                                .font(.caption.bold())
                                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                        }
                        HistoryFilterBar(filter: $vm.filter, entries: entries)
                    }
                }

                if filteredEntries.isEmpty {
                    DashboardCardView(title: module.rawValue) {
                        DashboardEmptyStateView(state: .init(
                            title: "Nessuna registrazione disponibile",
                            message: "Non ci sono dati reali per questo modulo nel periodo selezionato.",
                            actionTitle: nil
                        ))
                    }
                } else {
                    DashboardCardView(title: "Registrazioni per data") {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(groupedEntries, id: \.date) { group in
                                HistoryDateSection(date: group.date, entries: group.entries)
                            }
                        }
                    }

                    if hasMore {
                        Button {
                            visibleCount += PerformanceConfig.historyPageSize
                        } label: {
                            Label(
                                "Carica altre (\(min(PerformanceConfig.historyPageSize, filteredEntries.count - visibleCount)))",
                                systemImage: "arrow.down.circle"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PremiumPressButtonStyle())
                    }
                }
            }
            .padding(24)
        }
        .background(ThemeManager.shared.colorBackground.ignoresSafeArea())
        .navigationTitle("Storia \(module.rawValue)")
        .onChange(of: vm.appliedFilter) { _, _ in
            visibleCount = PerformanceConfig.historyPageSize
        }
    }
}
