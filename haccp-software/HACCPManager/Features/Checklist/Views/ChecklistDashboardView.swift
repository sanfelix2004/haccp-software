import SwiftUI

struct ChecklistDashboardView: View {
    let runs: [ChecklistRun]
    let templates: [ChecklistTemplate]
    let itemResults: [ChecklistItemResult]
    let alerts: [ChecklistAlert]
    let counts: (todo: Int, inProgress: Int, completed: Int, critical: Int)
    let onCreateTemplate: () -> Void
    let canCreate: Bool
    let onOpenRun: (ChecklistRun) -> Void

    private var activeRuns: [ChecklistRun] {
        runs.filter { $0.status != .completed && $0.status != .archived && $0.status != .failed }
    }

    private var overdueRuns: [ChecklistRun] {
        activeRuns.filter { $0.status == .overdue }.sorted(by: { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) })
    }

    private var todayRuns: [ChecklistRun] {
        let calendar = Calendar.current
        return activeRuns.filter {
            guard let dueAt = $0.dueAt else { return false }
            return calendar.isDateInToday(dueAt) && $0.status != .overdue && frequency(for: $0) == .daily
        }.sorted(by: { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) })
    }

    private var weeklyUpcomingRuns: [ChecklistRun] {
        let now = Date()
        let limit = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        return activeRuns.filter {
            guard let dueAt = $0.dueAt else { return false }
            return dueAt >= now && dueAt <= limit && frequency(for: $0) == .weekly
        }.sorted(by: { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) })
    }

    private var monthlyUpcomingRuns: [ChecklistRun] {
        let now = Date()
        let limit = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        return activeRuns.filter {
            guard let dueAt = $0.dueAt else { return false }
            return dueAt >= now && dueAt <= limit && frequency(for: $0) == .monthly
        }.sorted(by: { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) })
    }

    private var hasAnySectionContent: Bool {
        !overdueRuns.isEmpty || !todayRuns.isEmpty || !weeklyUpcomingRuns.isEmpty || !monthlyUpcomingRuns.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    metric("Da fare", value: counts.todo, color: .yellow)
                    metric("In corso", value: counts.inProgress, color: .orange)
                    metric("Completate", value: counts.completed, color: .green)
                    metric("Criticita", value: counts.critical, color: .red)
                }

                if !hasAnySectionContent {
                    ChecklistEmptyStateView(
                        title: "Nessuna checklist attiva oggi",
                        message: "Avvia una checklist dalla sezione Modelli.",
                        actionTitle: canCreate ? "Crea checklist" : nil,
                        action: canCreate ? onCreateTemplate : nil
                    )
                } else {
                    VStack(spacing: 10) {
                        if !overdueRuns.isEmpty {
                            section(title: "Checklist in ritardo", runs: overdueRuns)
                        }
                        if !todayRuns.isEmpty {
                            section(title: "Checklist di oggi", runs: todayRuns)
                        }
                        if !weeklyUpcomingRuns.isEmpty {
                            section(title: "Checklist settimanali in scadenza", runs: weeklyUpcomingRuns)
                        }
                        if !monthlyUpcomingRuns.isEmpty {
                            section(title: "Checklist mensili in scadenza", runs: monthlyUpcomingRuns)
                        }
                    }
                }

                if !alerts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alert checklist attivi").foregroundColor(.white).font(.headline)
                        ForEach(alerts.prefix(5)) { alert in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                                Text(alert.message).foregroundColor(.white)
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(10)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func metric(_ title: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(.gray)
            Text("\(value)").font(.title2.bold()).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.14))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func section(title: String, runs: [ChecklistRun]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(runs.prefix(8)) { run in
                let summary = progressSummary(for: run)
                Button {
                    onOpenRun(run)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(run.templateTitleSnapshot).foregroundColor(.white).font(.headline)
                            Spacer()
                            Text(statusLabel(for: run, progress: summary.progressPercentage))
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(run.status.color.opacity(0.25))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        Text("\(summary.completed)/\(summary.total) completati · \(summary.progressPercentage)%")
                            .font(.caption)
                            .foregroundColor(.gray)
                        ProgressView(value: Double(summary.progressPercentage), total: 100)
                            .tint(progressTint(for: summary.progressPercentage))
                        if summary.hasFailures {
                            Text("Con criticita")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.25))
                                .cornerRadius(8)
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func statusLabel(for run: ChecklistRun, progress: Int) -> String {
        if progress <= 0 {
            return "Da iniziare"
        }
        if progress >= 100 {
            return "Completata"
        }

        switch run.status {
        case .inProgress, .notStarted, .overdue, .failed:
            return "\(progress)% completata"
        case .completed:
            return "Completata"
        case .archived:
            return "Archiviata"
        }
    }

    private func progressSummary(for run: ChecklistRun) -> (completed: Int, total: Int, progressPercentage: Int, hasFailures: Bool) {
        let scoped = itemResults.filter { $0.checklistRunId == run.id }
        let total = scoped.count
        guard total > 0 else {
            return (0, 0, 0, false)
        }
        let completed = scoped.filter {
            $0.result == .pass || $0.result == .fail || $0.result == .notApplicable
        }.count
        let hasFailures = scoped.contains(where: { $0.result == .fail })
        let percentage = Int((Double(completed) / Double(total) * 100).rounded())
        return (completed, total, percentage, hasFailures)
    }

    private func progressTint(for percentage: Int) -> Color {
        if percentage >= 100 { return .green }
        if percentage >= 50 { return .yellow }
        return .orange
    }

    private func frequency(for run: ChecklistRun) -> ChecklistFrequency? {
        templates.first(where: { $0.id == run.templateId })?.frequency
    }
}
