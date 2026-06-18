import SwiftUI

struct ChecklistHistoryView: View {
    let runs: [ChecklistRun]
    let templates: [ChecklistTemplate]
    @ObservedObject var vm: ChecklistHistoryViewModel

    @Environment(\.theme) private var theme

    private var filtered: [ChecklistRun] {
        vm.filteredRuns(runs: runs, templates: templates)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing.sectionSpacing) {
                ModuleScreenHeader(
                    title: "Storico checklist",
                    subtitle: "Esecuzioni completate e archiviate",
                    systemImage: "clock.arrow.circlepath"
                )

                DashboardCardView(title: "Filtri", subtitle: "\(filtered.count) risultati") {
                    VStack(alignment: .leading, spacing: 12) {
                        DatePicker("Dal", selection: $vm.fromDate, displayedComponents: .date)
                        DatePicker("Al", selection: $vm.toDate, displayedComponents: .date)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                HistoryFilterChip(title: "Tutte le categorie", isSelected: vm.categoryFilter == nil) {
                                    vm.categoryFilter = nil
                                }
                                ForEach(ChecklistCategory.allCases, id: \.self) { category in
                                    HistoryFilterChip(title: category.label, isSelected: vm.categoryFilter == category) {
                                        vm.categoryFilter = category
                                    }
                                }
                            }
                        }
                    }
                }

                if filtered.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessuna esecuzione",
                        message: "Lo storico si popola quando completi le checklist operative.",
                        actionTitle: nil
                    ))
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { run in
                            historyRow(run)
                        }
                    }
                }
            }
            .padding(theme.spacing.screenPadding)
        }
    }

    private func historyRow(_ run: ChecklistRun) -> some View {
        let template = templates.first(where: { $0.id == run.templateId })
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.colorPrimary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: template?.category.systemImage ?? "checklist")
                    .foregroundStyle(theme.colorPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(run.templateTitleSnapshot)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                if let name = run.completedByNameSnapshot {
                    Text("Operatore: \(name)")
                        .font(theme.typography.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                HACCPBadge(title: run.status.label, style: run.status.badgeStyle, showIcon: false)
                Text("\(Int(run.progressPercentage))%")
                    .font(theme.typography.caption.weight(.semibold))
                    .foregroundStyle(theme.colorTextSecondary)
            }
        }
        .padding(14)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
    }
}
