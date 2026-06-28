import SwiftUI

struct ChecklistDashboardView: View {
    let runs: [ChecklistRun]
    let templates: [ChecklistTemplate]
    let itemResults: [ChecklistItemResult]
    let counts: (todo: Int, inProgress: Int, completed: Int)
    let onCreateTemplate: () -> Void
    let onCreateQuickTask: () -> Void
    let canCreate: Bool
    let onOpenRun: (ChecklistRun) -> Void
    let onGoToTemplates: () -> Void

    @Environment(\.theme) private var theme

    private let engine = PeriodicTaskEngine()

    private var activeRuns: [ChecklistRun] {
        runs.filter { !$0.status.isTerminal }
    }

    private var inProgressRuns: [ChecklistRun] {
        activeRuns
            .filter { $0.status == .inProgress }
            .sorted { $0.startedAt > $1.startedAt }
    }

    /// Da fare oggi: solo controlli del giorno corrente (in ritardo solo se scadono oggi).
    private var todayRuns: [ChecklistRun] {
        activeRuns
            .filter { $0.status != .inProgress }
            .filter { run in
                guard run.status == .notStarted || run.status == .overdue else { return false }
                guard let frequency = frequency(for: run) else { return false }
                let adapter = ChecklistRunPeriodicAdapter(
                    run: run,
                    frequency: frequency,
                    category: template(for: run)?.category ?? .custom,
                    areaTag: template(for: run)?.areaTag
                )
                return engine.isVisibleOnDashboard(adapter)
            }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
    }

    private var hasAnySectionContent: Bool {
        !todayRuns.isEmpty || !inProgressRuns.isEmpty
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing.sectionSpacing) {
                ModuleScreenHeader(
                    title: "Checklist operative",
                    subtitle: "Solo i controlli di oggi · settimanali e mensili compaiono nel giorno previsto",
                    systemImage: "checklist"
                )
                .padding(.horizontal, theme.spacing.screenPadding)

                statsRow
                    .padding(.horizontal, theme.spacing.screenPadding)

                if !hasAnySectionContent {
                    DashboardCardView(title: "Nessuna checklist in scadenza", subtitle: "Routine leggera") {
                        DashboardEmptyStateView(state: .init(
                            title: "Tutto aggiornato per oggi",
                            message: "Le checklist settimanali, mensili e annuali compaiono automaticamente nel giorno previsto. I modelli restano sempre consultabili nel tab Modelli.",
                            actionTitle: "Vai ai modelli"
                        )) {
                            onGoToTemplates()
                        }
                        if canCreate {
                            VStack(spacing: 8) {
                                SecondaryButton(title: "Attività rapida", icon: "bolt.circle") {
                                    onCreateQuickTask()
                                }
                                SecondaryButton(title: "Crea modello", icon: "plus.circle") {
                                    onCreateTemplate()
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, theme.spacing.screenPadding)
                } else {
                    if !inProgressRuns.isEmpty {
                        runSection(title: "Riprendi in corso", subtitle: "\(inProgressRuns.count) avviate", runs: inProgressRuns)
                    }
                    if !todayRuns.isEmpty {
                        runSection(title: "Oggi", subtitle: todaySectionSubtitle, runs: todayRuns)
                    }
                }
            }
            .padding(.vertical, theme.spacing.screenPadding)
        }
    }

    private var todaySectionSubtitle: String {
        let dailies = todayRuns.filter { frequency(for: $0) == .daily }.count
        let periodic = todayRuns.count - dailies
        if periodic == 0 { return "Routine giornaliera" }
        if dailies == 0 { return "Controlli periodici di oggi" }
        return "Giornaliere e controlli periodici"
    }

    private var statsRow: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "Da fare",
                value: "\(counts.todo)",
                subtitle: "Visibili oggi",
                icon: "clock.badge.exclamationmark",
                accent: counts.todo > 0 ? theme.colorWarning : theme.colorTextSecondary
            )
            StatCard(
                title: "In corso",
                value: "\(counts.inProgress)",
                subtitle: "Avviate",
                icon: "play.circle.fill",
                accent: theme.colorInfo
            )
            StatCard(
                title: "Completate",
                value: "\(counts.completed)",
                subtitle: "Ciclo corrente",
                icon: "checkmark.seal.fill",
                accent: theme.colorSuccess
            )
        }
    }

    @ViewBuilder
    private func runSection(title: String, subtitle: String, runs: [ChecklistRun]) -> some View {
        DashboardCardView(title: title, subtitle: subtitle) {
            LazyVStack(spacing: 10) {
                ForEach(runs.prefix(12)) { run in
                    ChecklistRunCard(
                        run: run,
                        summary: ChecklistProgressSummary.from(run: run, results: itemResults),
                        category: template(for: run)?.category,
                        frequency: frequency(for: run),
                        onTap: { onOpenRun(run) }
                    )
                }
            }
        }
        .padding(.horizontal, theme.spacing.screenPadding)
    }

    private func template(for run: ChecklistRun) -> ChecklistTemplate? {
        templates.first(where: { $0.id == run.templateId })
    }

    private func frequency(for run: ChecklistRun) -> ChecklistFrequency? {
        template(for: run)?.frequency
    }
}
