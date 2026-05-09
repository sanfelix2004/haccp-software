import SwiftUI

struct HistoryModuleDetailView: View {
    let module: HistoryModule
    let entries: [HistoryEntry]
    @StateObject private var vm = HistoryModuleDetailViewModel()

    private var filteredEntries: [HistoryEntry] {
        vm.filtered(entries: entries).sorted { $0.date > $1.date }
    }

    private var groupedEntries: [(date: Date, entries: [HistoryEntry])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredEntries) { calendar.startOfDay(for: $0.date) }
        return groups
            .map { (date: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                DashboardCardView(title: "Storico \(module.rawValue)") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label(module.rawValue, systemImage: module.icon)
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(filteredEntries.count) registrazioni")
                                .font(.caption.bold())
                                .foregroundColor(.gray)
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
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(groupedEntries, id: \.date) { group in
                                HistoryDateSection(date: group.date, entries: group.entries)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Storia \(module.rawValue)")
    }
}
