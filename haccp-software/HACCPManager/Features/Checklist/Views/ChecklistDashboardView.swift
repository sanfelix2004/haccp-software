import SwiftUI

struct ChecklistDashboardView: View {
    let runs: [ChecklistRun]
    let templates: [ChecklistTemplate]
    let itemResults: [ChecklistItemResult]
    let alerts: [ChecklistAlert]
    let counts: (todo: Int, inProgress: Int, completed: Int, critical: Int)
    let onCreateTemplate: () -> Void
    let onCreateQuickTask: () -> Void
    let canCreate: Bool
    let onOpenRun: (ChecklistRun) -> Void
    let onGoToTemplates: () -> Void

    @Environment(\.theme) private var theme

    private var activeRuns: [ChecklistRun] {
        runs.filter { $0.status != .completed && $0.status != .archived && $0.status != .failed }
    }

    private var overdueRuns: [ChecklistRun] {
        activeRuns.filter { $0.status == .overdue }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
    }

    private var todayRuns: [ChecklistRun] {
        let calendar = Calendar.current
        return activeRuns.filter {
            guard let dueAt = $0.dueAt else { return false }
            return calendar.isDateInToday(dueAt) && $0.status != .overdue && frequency(for: $0) == .daily
        }.sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
    }

    private var weeklyUpcomingRuns: [ChecklistRun] {
        let now = Date()
        let limit = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        return activeRuns.filter {
            guard let dueAt = $0.dueAt else { return false }
            return dueAt >= now && dueAt <= limit && frequency(for: $0) == .weekly
        }.sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
    }

    private var monthlyUpcomingRuns: [ChecklistRun] {
        let now = Date()
        let limit = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        return activeRuns.filter {
            guard let dueAt = $0.dueAt else { return false }
            return dueAt >= now && dueAt <= limit && frequency(for: $0) == .monthly
        }.sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
    }

    private var inProgressRuns: [ChecklistRun] {
        activeRuns.filter { $0.status == .inProgress }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private var activeAlerts: [ChecklistAlert] {
        alerts.filter(\.isActive).sorted { $0.createdAt > $1.createdAt }
    }

    private var hasAnySectionContent: Bool {
        !overdueRuns.isEmpty || !todayRuns.isEmpty || !weeklyUpcomingRuns.isEmpty
            || !monthlyUpcomingRuns.isEmpty || !inProgressRuns.isEmpty
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing.sectionSpacing) {
                ModuleScreenHeader(
                    title: "Checklist operative",
                    subtitle: "Controlli giornalieri, settimanali e mensili HACCP",
                    systemImage: "checklist"
                )
                .padding(.horizontal, theme.spacing.screenPadding)

                statsRow
                    .padding(.horizontal, theme.spacing.screenPadding)

                if !hasAnySectionContent {
                    DashboardCardView(title: "Nessuna checklist in scadenza", subtitle: "Avvia da un modello") {
                        DashboardEmptyStateView(state: .init(
                            title: "Tutto aggiornato",
                            message: "Non ci sono checklist da completare ora. Avvia un controllo dai modelli o creane uno nuovo.",
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
                    if !overdueRuns.isEmpty {
                        runSection(title: "In ritardo", subtitle: "Da completare subito", runs: overdueRuns)
                    }
                    if !todayRuns.isEmpty {
                        runSection(title: "Oggi", subtitle: "Checklist giornaliere", runs: todayRuns)
                    }
                    if !weeklyUpcomingRuns.isEmpty {
                        runSection(title: "Settimana", subtitle: "Prossimi 7 giorni", runs: weeklyUpcomingRuns)
                    }
                    if !monthlyUpcomingRuns.isEmpty {
                        runSection(title: "Mese", subtitle: "Prossimi 30 giorni", runs: monthlyUpcomingRuns)
                    }
                }

                if !activeAlerts.isEmpty {
                    DashboardCardView(title: "Criticità aperte", subtitle: "\(activeAlerts.count) da gestire") {
                        VStack(spacing: 10) {
                            ForEach(activeAlerts.prefix(4)) { alert in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(theme.colorError)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(alert.message)
                                            .font(theme.typography.subheadline)
                                            .foregroundStyle(theme.colorTextPrimary)
                                        Text(alert.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(theme.typography.caption)
                                            .foregroundStyle(theme.colorTextSecondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(12)
                                .background(theme.colorError.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                    .padding(.horizontal, theme.spacing.screenPadding)
                }
            }
            .padding(.vertical, theme.spacing.screenPadding)
        }
    }

    private var statsRow: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "Da fare",
                value: "\(counts.todo)",
                subtitle: "Non iniziate / ritardo",
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
            StatCard(
                title: "Criticità",
                value: "\(counts.critical)",
                subtitle: "Alert attivi",
                icon: "exclamationmark.triangle.fill",
                accent: counts.critical > 0 ? theme.colorError : theme.colorTextSecondary
            )
        }
    }

    @ViewBuilder
    private func runSection(title: String, subtitle: String, runs: [ChecklistRun]) -> some View {
        DashboardCardView(title: title, subtitle: subtitle) {
            LazyVStack(spacing: 10) {
                ForEach(runs.prefix(8)) { run in
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
