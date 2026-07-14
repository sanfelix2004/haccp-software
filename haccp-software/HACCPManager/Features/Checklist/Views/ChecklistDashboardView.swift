import SwiftUI
import SwiftData

/// Lista piatta e immediata: apri Checklist → vedi subito cosa fare.
struct ChecklistDashboardView: View {
    let runs: [ChecklistRun]
    let templates: [ChecklistTemplate]
    let itemResults: [ChecklistItemResult]
    let counts: (todo: Int, inProgress: Int, completed: Int)
    let isRefreshing: Bool
    let service: ChecklistService
    let user: LocalUser?
    let canExecute: Bool
    let onCreateTemplate: () -> Void
    let onCreateQuickTask: () -> Void
    let canCreate: Bool
    let onOpenRun: (ChecklistRun) -> Void
    let onBrowseTemplates: () -> Void
    let onDataChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @State private var errorMessage: String?
    @State private var showBulkConfirm = false

    private let engine = PeriodicTaskEngine()

    private var activeRuns: [ChecklistRun] {
        runs.filter { !$0.status.isTerminal }
    }

    private var actionableRuns: [ChecklistRun] {
        let inProgress = activeRuns
            .filter { $0.status == .inProgress }
            .sorted { $0.startedAt > $1.startedAt }

        let today = activeRuns
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

        var seen = Set<UUID>()
        return (inProgress + today)
            .filter { seen.insert($0.id).inserted }
            .sorted(by: sortActionable)
    }

    private var incompleteRuns: [ChecklistRun] {
        actionableRuns.filter(isIncomplete)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if isRefreshing, actionableRuns.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Aggiornamento controlli…")
                            .font(.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                if actionableRuns.isEmpty, !isRefreshing {
                    emptyState
                } else {
                    if canExecute, !incompleteRuns.isEmpty {
                        completeAllButton
                    }

                    LazyVStack(spacing: 8) {
                        ForEach(actionableRuns) { run in
                            ChecklistInlineRunRow(
                                run: run,
                                template: template(for: run),
                                areaLabel: areaLabel(for: run),
                                summary: ChecklistProgressSummary.from(run: run, results: itemResults),
                                canExecute: canExecute,
                                onComplete: { completeSingle(run) },
                                onOpen: { onOpenRun(run) }
                            )
                        }
                    }
                }
            }
            .padding(.vertical, theme.spacing.screenPadding)
        }
        .alert("Checklist", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Segna tutto conforme", isPresented: $showBulkConfirm) {
            Button("Annulla", role: .cancel) {}
            Button("Conferma") {
                completeRuns(incompleteRuns)
            }
        } message: {
            Text("Segnare tutte le \(incompleteRuns.count) checklist aperte come conformi?")
        }
    }

    private var completeAllButton: some View {
        Button {
            showBulkConfirm = true
        } label: {
            Label("Segna tutto conforme (\(incompleteRuns.count))", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(theme.colorSuccess)
    }

    private var emptyState: some View {
        DashboardEmptyStateView(state: .init(
            title: "Nessun controllo oggi",
            message: "Le checklist periodiche compaiono nel giorno previsto. Avviane una dal tab Modelli.",
            actionTitle: canCreate ? "Apri Modelli" : nil
        )) {
            onBrowseTemplates()
        }
    }

    // MARK: - Azioni

    private func completeSingle(_ run: ChecklistRun) {
        guard isIncomplete(run) else { return }
        if let template = template(for: run), !template.supportsBulkPass {
            onOpenRun(run)
            return
        }
        completeRuns([run])
    }

    private func completeRuns(_ targetRuns: [ChecklistRun]) {
        guard let user else {
            errorMessage = "Accedi per completare le checklist."
            return
        }
        let actionable = targetRuns.filter(isIncomplete)
        guard !actionable.isEmpty else { return }
        do {
            let count = try service.completeAllChecklistRuns(
                runs: actionable,
                user: user,
                restaurantId: actionable[0].restaurantId,
                modelContext: modelContext
            )
            if count > 0 {
                HapticManager.shared.notification(.success)
                onDataChanged()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func isIncomplete(_ run: ChecklistRun) -> Bool {
        run.status != .completed && run.status != .failed && run.progressPercentage < 100
    }

    private func sortActionable(_ lhs: ChecklistRun, _ rhs: ChecklistRun) -> Bool {
        let lp = priority(lhs)
        let rp = priority(rhs)
        if lp != rp { return lp < rp }
        return (lhs.dueAt ?? .distantFuture) < (rhs.dueAt ?? .distantFuture)
    }

    private func priority(_ run: ChecklistRun) -> Int {
        if run.status == .overdue { return 0 }
        if run.status == .inProgress { return 1 }
        if isIncomplete(run) { return 2 }
        return 3
    }

    private func areaLabel(for run: ChecklistRun) -> String? {
        let tag = template(for: run)?.areaTag?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (tag?.isEmpty == false) ? tag : nil
    }

    private func template(for run: ChecklistRun) -> ChecklistTemplate? {
        templates.first(where: { $0.id == run.templateId })
    }

    private func frequency(for run: ChecklistRun) -> ChecklistFrequency? {
        template(for: run)?.frequency
    }
}

// MARK: - Riga compatta

private struct ChecklistInlineRunRow: View {
    @Bindable var run: ChecklistRun
    let template: ChecklistTemplate?
    let areaLabel: String?
    let summary: ChecklistProgressSummary
    let canExecute: Bool
    let onComplete: () -> Void
    let onOpen: () -> Void

    @Environment(\.theme) private var theme

    private var isDone: Bool {
        run.status == .completed || run.progressPercentage >= 100
    }

    private var isFailed: Bool {
        run.status == .failed || summary.hasFailures
    }

    private var allowsQuickComplete: Bool {
        template?.supportsBulkPass ?? true
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(run.templateTitleSnapshot)
                        .font(.subheadline.bold())
                        .foregroundStyle(theme.colorTextPrimary)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        if let areaLabel {
                            Text(areaLabel)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(theme.colorPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.colorPrimary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        if run.status == .overdue {
                            Text("In ritardo")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(theme.colorError)
                        } else if run.status == .inProgress {
                            Text("In corso \(summary.completed)/\(summary.total)")
                                .font(.caption2)
                                .foregroundStyle(theme.colorInfo)
                        } else if let dueAt = run.dueAt {
                            Text(dueLabel(dueAt))
                                .font(.caption2)
                                .foregroundStyle(theme.colorTextSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            actionControl
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.colorSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var actionControl: some View {
        if isDone {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(theme.colorSuccess)
        } else if isFailed {
            Button(action: onOpen) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(theme.colorError)
            }
            .buttonStyle(.plain)
        } else if canExecute {
            Button(action: onComplete) {
                Image(systemName: allowsQuickComplete ? "circle" : "chevron.right.circle")
                    .font(.title2)
                    .foregroundStyle(theme.colorPrimary)
            }
            .buttonStyle(.plain)
        } else {
            Image(systemName: "circle")
                .font(.title2)
                .foregroundStyle(theme.colorTextSecondary.opacity(0.4))
        }
    }

    private var borderColor: Color {
        if run.status == .overdue || isFailed { return theme.colorWarning.opacity(0.5) }
        if isDone { return theme.colorSuccess.opacity(0.35) }
        return theme.colorDivider
    }

    private func dueLabel(_ dueAt: Date) -> String {
        if Calendar.current.isDateInToday(dueAt) {
            return "Oggi \(dueAt.formatted(date: .omitted, time: .shortened))"
        }
        return dueAt.formatted(date: .abbreviated, time: .shortened)
    }
}
