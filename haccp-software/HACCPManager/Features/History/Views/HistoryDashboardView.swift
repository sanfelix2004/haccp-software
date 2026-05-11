import SwiftUI

struct HistoryDashboardView: View {
    let entries: [HistoryEntry]

    private var entriesByModule: [HistoryModule: [HistoryEntry]] {
        Dictionary(grouping: entries, by: \.module)
    }

    var body: some View {
        ScrollView {
            DashboardCardView(title: "Storia") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Archivio centrale HACCP")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                        ForEach(HistoryModule.dashboardModules) { module in
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
            .padding(24)
        }
        .background(ThemeManager.shared.colorBackground.ignoresSafeArea())
        .navigationTitle("Storia")
    }
}
