import SwiftUI
import SwiftData

/// Dashboard operativa pulizie: macro-aree espandibili con check inline.
struct CleaningDashboardView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case oggi = "Oggi"
        case ritardo = "In ritardo"
        case completate = "Completate"

        var id: String { rawValue }
    }

    private struct AreaSection: Identifiable {
        let id: String
        let name: String
        let isUnassigned: Bool

        init(area: CleaningArea) {
            id = "area:\(CleaningAreaGrouping.normalizeName(area.name))"
            name = area.name
            isUnassigned = false
        }

        init(unassigned: Void = ()) {
            id = CleaningDashboardView.unassignedSectionKey
            name = "Senza area"
            isUnassigned = true
        }

        init(tagName: String) {
            id = "tag:\(tagName.lowercased())"
            name = tagName
            isUnassigned = tagName == "Senza area"
        }
    }

    private static let unassignedSectionKey = "unassigned"

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    let areas: [CleaningArea]
    let runs: [ChecklistRun]
    let templates: [ChecklistTemplate]
    let service: ChecklistService
    let user: LocalUser?
    let canExecute: Bool
    let onSync: () -> Void

    @State private var selectedTab: Tab = .oggi
    @State private var expandedAreaIds: Set<String> = []
    @State private var errorMessage: String?
    @State private var pendingBulkAreaName: String?

    private let engine = PeriodicTaskEngine()

    private var templateById: [UUID: ChecklistTemplate] {
        Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
    }

    var body: some View {
        VStack(spacing: 16) {
            Picker("Filtro pulizie", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            areaGroupedList(
                runsForTab(selectedTab),
                emptyText: emptyText(for: selectedTab)
            )
        }
        .alert("Pulizie", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Completa Tutti", isPresented: Binding(
            get: { pendingBulkAreaName != nil },
            set: { if !$0 { pendingBulkAreaName = nil } }
        )) {
            Button("Annulla", role: .cancel) {
                pendingBulkAreaName = nil
            }
            Button("Completa Tutti") {
                if let name = pendingBulkAreaName {
                    completeAllInArea(named: name)
                }
                pendingBulkAreaName = nil
            }
        } message: {
            if let name = pendingBulkAreaName {
                Text("Segnare come completati tutti i controlli pulizia aperti in «\(name)»?")
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            autoExpandAreasWithPendingWork(in: runsForTab(newTab))
        }
        .onAppear {
            autoExpandAreasWithPendingWork(in: runsForTab(selectedTab))
        }
    }

    // MARK: - Macro aree espandibili

    private func areaGroupedList(_ tabRuns: [ChecklistRun], emptyText: String) -> some View {
        Group {
            if areaSections(for: tabRuns).isEmpty {
                cleaningNeutralEmptyState(
                    title: "Nessun dato",
                    message: emptyText
                )
            } else {
                VStack(spacing: 14) {
                    ForEach(areaSections(for: tabRuns)) { section in
                        let sectionRuns = runs(for: section, in: tabRuns)
                        collapsibleAreaSection(
                            section: section,
                            runs: sectionRuns,
                            emptyText: emptyText
                        )
                    }
                }
            }
        }
    }

    /// Empty state neutro (niente icona errore rossa).
    private func cleaningNeutralEmptyState(title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(theme.colorTextSecondary.opacity(0.55))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.colorTextSecondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(theme.colorTextSecondary.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
    }

    private func areaSections(for tabRuns: [ChecklistRun]) -> [AreaSection] {
        if areas.isEmpty {
            return areaNames(in: tabRuns).map { AreaSection(tagName: $0) }
        }

        var sections = CleaningAreaGrouping.uniqueByName(areas)
            .map { AreaSection(area: $0) }

        if !unmatchedRuns(in: tabRuns).isEmpty {
            sections.append(AreaSection(unassigned: ()))
        }

        return sections
    }

    private func collapsibleAreaSection(
        section: AreaSection,
        runs sectionRuns: [ChecklistRun],
        emptyText: String
    ) -> some View {
        let isExpanded = expandedAreaIds.contains(section.id)
        let completed = sectionRuns.filter { $0.statusRaw == ChecklistRunStatus.completed.rawValue }.count
        let total = sectionRuns.count
        let hasOpen = sectionRuns.contains { $0.statusRaw != ChecklistRunStatus.completed.rawValue }

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        toggleArea(section.id)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                            .font(.title3)
                            .foregroundStyle(theme.colorPrimary)

                        VStack(alignment: .leading, spacing: 4) {
                            Label(section.name, systemImage: "square.grid.2x2")
                                .font(.headline)
                                .foregroundStyle(theme.colorTextPrimary)
                                .labelStyle(.titleAndIcon)

                            if total == 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "eye.slash")
                                        .font(.caption2)
                                    Text("Nessun dato")
                                        .font(.caption)
                                }
                                .foregroundStyle(theme.colorTextSecondary.opacity(0.75))
                            } else {
                                Text("\(completed)/\(total) completati")
                                    .font(.caption)
                                    .foregroundStyle(theme.colorTextSecondary)
                            }
                        }

                        Spacer(minLength: 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Completa Tutti: sul header, senza dover espandere la card.
                if canExecute, hasOpen {
                    Button {
                        pendingBulkAreaName = section.name
                    } label: {
                        Label("Completa Tutti", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.colorSuccess)
                    .accessibilityHint("Segna completati tutti i task di \(section.name)")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    if sectionRuns.isEmpty {
                        cleaningNeutralEmptyState(title: "Nessun dato", message: emptyText)
                            .padding(.horizontal, 4)
                    } else {
                        ForEach(sectionRuns) { run in
                            CleaningInlineTaskRow(
                                run: run,
                                template: templateById[run.templateId],
                                canExecute: canExecute,
                                onComplete: { completeInline(run) }
                            )
                            .padding(.horizontal, 10)
                        }
                    }
                }
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.colorSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isExpanded ? theme.colorPrimary.opacity(0.32) : theme.colorDivider, lineWidth: 1)
                )
        )
    }

    private func toggleArea(_ areaId: String) {
        if expandedAreaIds.contains(areaId) {
            expandedAreaIds.remove(areaId)
        } else {
            expandedAreaIds.insert(areaId)
        }
    }

    private func autoExpandAreasWithPendingWork(in tabRuns: [ChecklistRun]) {
        guard expandedAreaIds.isEmpty else { return }
        let pendingSectionIds = areaSections(for: tabRuns).compactMap { section -> String? in
            let sectionRuns = runs(for: section, in: tabRuns)
            let hasOpen = sectionRuns.contains {
                $0.statusRaw != ChecklistRunStatus.completed.rawValue
            }
            return hasOpen ? section.id : nil
        }
        if pendingSectionIds.count == 1, let only = pendingSectionIds.first {
            expandedAreaIds.insert(only)
        }
    }

    private func runs(for section: AreaSection, in tabRuns: [ChecklistRun]) -> [ChecklistRun] {
        if section.isUnassigned {
            return unmatchedRuns(in: tabRuns)
        }
        if areas.isEmpty {
            return tabRuns.filter {
                areaTag(for: $0).localizedCaseInsensitiveCompare(section.name) == .orderedSame
            }
        }
        return tabRuns.filter {
            areaTag(for: $0).localizedCaseInsensitiveCompare(section.name) == .orderedSame
        }
    }

    private func unmatchedRuns(in tabRuns: [ChecklistRun]) -> [ChecklistRun] {
        let configuredNames = Set(areas.map { $0.name.lowercased() })
        return tabRuns.filter { run in
            !configuredNames.contains(areaTag(for: run).lowercased())
        }
    }

    private func emptyText(for tab: Tab) -> String {
        switch tab {
        case .oggi: return "Nessun controllo da fare oggi in quest'area."
        case .ritardo: return "Nessun controllo in ritardo in quest'area."
        case .completate: return "Nessun controllo completato in quest'area nel ciclo corrente."
        }
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

    private func completeAllInArea(named areaName: String) {
        guard let user else {
            errorMessage = "Accedi per registrare la pulizia."
            return
        }
        let tabRuns = runsForTab(selectedTab)
        let targetRuns: [ChecklistRun]
        if areaName == "Senza area" {
            targetRuns = unmatchedRuns(in: tabRuns).filter { $0.status != .completed }
        } else {
            targetRuns = tabRuns.filter {
                areaTag(for: $0).localizedCaseInsensitiveCompare(areaName) == .orderedSame
                    && $0.status != .completed
            }
        }
        guard !targetRuns.isEmpty else { return }
        do {
            let count = try service.completeAllCleaningRuns(
                runs: targetRuns,
                user: user,
                restaurantId: targetRuns[0].restaurantId,
                modelContext: modelContext
            )
            if count > 0 {
                HapticManager.shared.notification(.success)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

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
