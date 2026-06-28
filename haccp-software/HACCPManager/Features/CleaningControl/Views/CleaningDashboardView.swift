import SwiftUI
import SwiftData

/// Dashboard operativa pulizie: stesso motore checklist, UX inline senza fogli di dettaglio.
struct CleaningDashboardView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case oggi = "Oggi"
        case ritardo = "In ritardo"
        case completate = "Completate"

        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    let runs: [ChecklistRun]
    let templates: [ChecklistTemplate]
    let service: ChecklistService
    let user: LocalUser?
    let canExecute: Bool
    let onSync: () -> Void

    @State private var selectedTab: Tab = .oggi
    @State private var errorMessage: String?

    private let engine = PeriodicTaskEngine()

    private var templateById: [UUID: ChecklistTemplate] {
        Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
    }

    var body: some View {
        VStack(spacing: 14) {
            Picker("Filtro pulizie", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch selectedTab {
                case .oggi:
                    areaGroupedList(runsForTab(.oggi), emptyText: "Nessun task da fare oggi.")
                case .ritardo:
                    areaGroupedList(runsForTab(.ritardo), emptyText: "Nessun task in ritardo.")
                case .completate:
                    areaGroupedList(runsForTab(.completate), emptyText: "Nessun task completato nel ciclo corrente.")
                }
            }
        }
        .alert("Pulizie", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear { onSync() }
    }

    // MARK: - Raggruppamento per area

    private func areaGroupedList(_ runs: [ChecklistRun], emptyText: String) -> some View {
        Group {
            if runs.isEmpty {
                DashboardEmptyStateView(state: .init(title: "Nessun elemento", message: emptyText, actionTitle: nil))
            } else {
                VStack(spacing: 14) {
                    ForEach(areaNames(in: runs), id: \.self) { area in
                        let areaRuns = runs.filter { areaTag(for: $0) == area }
                        areaSection(areaName: area, runs: areaRuns)
                    }
                }
            }
        }
    }

    private func areaSection(areaName: String, runs: [ChecklistRun]) -> some View {
        let completed = runs.filter { $0.statusRaw == ChecklistRunStatus.completed.rawValue }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(areaName, systemImage: "square.grid.2x2")
                    .font(.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                Spacer()
                Text("\(completed)/\(runs.count)")
                    .font(.caption.bold())
                    .foregroundStyle(theme.colorTextSecondary)
            }
            ProgressView(value: runs.isEmpty ? 0 : Double(completed) / Double(runs.count))
                .tint(theme.colorSuccess)

            ForEach(runs) { run in
                CleaningInlineTaskRow(
                    run: run,
                    template: templateById[run.templateId],
                    canExecute: canExecute,
                    onComplete: { completeInline(run) }
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.colorSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.colorDivider, lineWidth: 1)
                )
        )
    }

    // MARK: - Filtri tab

    private func runsForTab(_ tab: Tab) -> [ChecklistRun] {
        switch tab {
        case .oggi:
            return visibleOpenRuns.filter { $0.status != .overdue }
        case .ritardo:
            return visibleOpenRuns.filter { $0.status == .overdue }
        case .completate:
            return runs
                .filter { $0.status == .completed && isVisibleInCurrentCycle($0) }
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        }
    }

    private var visibleOpenRuns: [ChecklistRun] {
        runs
            .filter { !$0.status.isTerminal }
            .filter { isVisibleInCurrentCycle($0) }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
    }

    private func isVisibleInCurrentCycle(_ run: ChecklistRun) -> Bool {
        guard let template = templateById[run.templateId] else { return false }
        let adapter = ChecklistRunPeriodicAdapter(
            run: run,
            frequency: template.frequency,
            category: .cleaning,
            areaTag: template.areaTag
        )
        if run.status == .inProgress { return true }
        if run.status == .completed {
            guard let completedAt = run.completedAt else { return false }
            return Calendar.current.isDateInToday(completedAt)
                || engine.isInCurrentCycle(task: adapter, now: Date())
        }
        return engine.isVisibleOnDashboard(adapter)
    }

    // MARK: - Azioni

    private func completeInline(_ run: ChecklistRun) {
        guard let user else {
            errorMessage = "Accedi per registrare la pulizia."
            return
        }
        do {
            try service.inlineCompleteCleaningRun(
                run: run,
                user: user,
                restaurantId: run.restaurantId,
                modelContext: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func areaTag(for run: ChecklistRun) -> String {
        templateById[run.templateId]?.areaTag?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (templateById[run.templateId]?.areaTag ?? "Senza area")
            : "Senza area"
    }

    private func areaNames(in runs: [ChecklistRun]) -> [String] {
        Array(Set(runs.map { areaTag(for: $0) })).sorted()
    }
}

// MARK: - Riga osservabile (@Bindable per refresh SwiftData immediato)

private struct CleaningInlineTaskRow: View {
    @Bindable var run: ChecklistRun
    let template: ChecklistTemplate?
    let canExecute: Bool
    let onComplete: () -> Void

    @Environment(\.theme) private var theme

    private var isDone: Bool {
        run.statusRaw == ChecklistRunStatus.completed.rawValue
    }

    private var isOverdue: Bool {
        run.statusRaw == ChecklistRunStatus.overdue.rawValue
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(taskTitle)
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.colorTextPrimary)
                if let template {
                    Text(template.frequency.label)
                        .font(.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                }
                if let dueAt = run.dueAt {
                    Text(dueDescription(for: dueAt, isOverdue: isOverdue))
                        .font(.caption2)
                        .foregroundStyle(isOverdue ? theme.colorError : theme.colorTextSecondary)
                }
                if isDone, let completedAt = run.completedAt {
                    Text("Completato \(completedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(theme.colorSuccess)
                }
            }

            Spacer(minLength: 8)

            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(theme.colorSuccess)
            } else if canExecute {
                Button(action: onComplete) {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundStyle(theme.colorPrimary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Segna come fatto")
            } else {
                Image(systemName: "circle")
                    .font(.title2)
                    .foregroundStyle(theme.colorTextSecondary.opacity(0.4))
            }
        }
        .padding(10)
        .background(theme.colorBackground.opacity(0.5))
        .cornerRadius(10)
    }

    private var taskTitle: String {
        if let template, template.isCleaningBridge {
            let parts = template.title.split(separator: "·", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 { return String(parts[1]) }
        }
        return template?.title ?? run.templateTitleSnapshot
    }

    private func dueDescription(for dueAt: Date, isOverdue: Bool) -> String {
        if isOverdue {
            return "Scaduto il \(dueAt.formatted(date: .abbreviated, time: .shortened))"
        }
        if Calendar.current.isDateInToday(dueAt) {
            return "Scadenza: oggi alle \(dueAt.formatted(date: .omitted, time: .shortened))"
        }
        return "Scadenza: \(dueAt.formatted(date: .abbreviated, time: .shortened))"
    }
}
