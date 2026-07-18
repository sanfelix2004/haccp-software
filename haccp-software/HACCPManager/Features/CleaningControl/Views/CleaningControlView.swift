import SwiftUI
import SwiftData

struct CleaningControlView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @ObservedObject private var dataStore = ModuleStoreRegistry.shared.cleaningControl
    @StateObject private var vm = CleaningControlViewModel()
    private let cleaningBFF = CleaningTaskBFF()
    private let checklistService = ChecklistService()
    @State private var pendingCriticalityRecord: CleaningRecord?
    @State private var showCriticalitySheet = false
    @State private var pendingCriticalityOriginalOutcome: CleaningTaskOutcome?
    @State private var showManageSheet = false
    @State private var masterAuth = MasterAuthCoordinator()
    @State private var selectedAreaIdForNewTask: UUID?
    @State private var newAreaName: String = ""
    @State private var newTaskName: String = ""
    @State private var newTaskFrequency: CleaningTaskFrequency = .giornaliero
    @State private var newTaskCustomDays: String = ""
    @State private var maintenanceTask: Task<Void, Never>?

    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }

    private var canUseCleaningConfig: Bool {
        permissions.canPerform(.manageCleaningConfiguration)
    }

    private var permissions: UserPermissions { currentUser.permissions }
    private var canManageCleaning: Bool { permissions.can(.manageCleaningConfiguration) }
    private var canClearHistory: Bool { permissions.can(.clearCleaningHistory) }
    private var canExecute: Bool { permissions.can(.executeRecords) }

    private var scopedAreas: [CleaningArea] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return CleaningAreaGrouping.uniqueByName(
            dataStore.areas.filter { $0.restaurantId == rid }
        )
    }

    private var scopedTasks: [CleaningTask] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return dataStore.tasks.filter { $0.restaurantId == rid }
    }

    private var scopedRecords: [CleaningRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return dataStore.records.filter { $0.restaurantId == rid }
    }

    private var completedCleaningRuns: [ChecklistRun] {
        guard let rid = appState.activeRestaurantId else { return [] }
        let templateIds = Set(cleaningTemplates.map(\.id))
        return dataStore.checklistRuns
            .filter { $0.restaurantId == rid && templateIds.contains($0.templateId) }
            .filter { $0.status == .completed || $0.status == .failed || $0.status == .missed || $0.status == .archived }
            .sorted { ($0.completedAt ?? $0.startedAt) > ($1.completedAt ?? $1.startedAt) }
    }

    private var templateById: [UUID: ChecklistTemplate] {
        HACCPSafeParse.dictionary(cleaningTemplates.map { ($0.id, $0) })
    }

    private func areaTag(for run: ChecklistRun) -> String {
        templateById[run.templateId]?.areaTag?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (templateById[run.templateId]?.areaTag ?? "Senza area")
            : "Senza area"
    }

    private func areaNames(for runs: [ChecklistRun]) -> [String] {
        Array(Set(runs.map { areaTag(for: $0) })).sorted()
    }

    private func taskTitle(for run: ChecklistRun) -> String {
        if let template = templateById[run.templateId], template.isCleaningBridge {
            let parts = template.title.split(separator: "·", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 { return String(parts[1]) }
        }
        return templateById[run.templateId]?.title ?? run.templateTitleSnapshot
    }

    private func badgeStyle(for status: ChecklistRunStatus) -> HACCPBadgeStyle {
        switch status {
        case .completed: return .conforme
        case .failed: return .nonConforme
        case .missed: return .warning
        case .archived: return .neutral
        default: return .info
        }
    }

    private func periodDescription(for run: ChecklistRun) -> String {
        let start = run.startedAt.formatted(date: .abbreviated, time: .shortened)
        let end = run.dueAt?.formatted(date: .abbreviated, time: .shortened) ?? "—"
        return "Ciclo: \(start) → \(end)"
    }

    private func automaticTimestampDescription(for run: ChecklistRun) -> String {
        if let completedAt = run.completedAt {
            return "Registrato il: \(completedAt.formatted(date: .abbreviated, time: .shortened))"
        }
        return "Scaduto il: \(run.dueAt?.formatted(date: .abbreviated, time: .shortened) ?? "—")"
    }

    private func runDetails(for run: ChecklistRun) -> (notes: String, action: String) {
        let results = dataStore.checklistItemResults.filter { $0.checklistRunId == run.id }
        let notesParts = results.compactMap { $0.note }.filter { !$0.isEmpty }
        let notes = notesParts.joined(separator: " · ")
        let fails = results.filter { $0.result == .fail }.map(\.titleSnapshot).joined(separator: " · ")
        return (notes: (run.notes ?? "").isEmpty ? notes : (run.notes ?? ""), action: fails)
    }

    private var scopedCriticalities: [CleaningCriticality] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return dataStore.criticalities.filter { $0.restaurantId == rid }
    }

    private var cleaningTemplates: [ChecklistTemplate] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return dataStore.checklistTemplates.filter {
            $0.restaurantId == rid && $0.isActive && $0.matchesCleaningModuleFilter
        }
    }

    private var cleaningRuns: [ChecklistRun] {
        guard let rid = appState.activeRestaurantId else { return [] }
        let templateIds = Set(cleaningTemplates.map(\.id))
        return dataStore.checklistRuns.filter {
            $0.restaurantId == rid && !$0.isArchived && templateIds.contains($0.templateId)
        }
    }

    private var runBasedSummary: CleaningSummary {
        let engine = PeriodicTaskEngine()
        let templateById = Dictionary(uniqueKeysWithValues: cleaningTemplates.map { ($0.id, $0) })
        let relevant = cleaningRuns.filter { run in
            guard let template = templateById[run.templateId] else { return false }
            let adapter = ChecklistRunPeriodicAdapter(
                run: run,
                frequency: template.frequency,
                category: .cleaning,
                areaTag: template.areaTag
            )
            if run.status == .completed {
                return engine.isInCurrentCycle(task: adapter, now: Date())
            }
            if run.status.isTerminal { return false }
            return engine.isVisibleOnDashboard(adapter) || run.status == .inProgress
        }
        let completed = relevant.filter { $0.status == .completed }.count
        return CleaningSummary(completed: completed, total: relevant.count)
    }

    private var hasOperationalContent: Bool {
        !scopedTasks.isEmpty || !cleaningTemplates.isEmpty || !cleaningRuns.isEmpty || !scopedAreas.isEmpty
    }

    var body: some View {
        Group {
            if dataStore.isLoading && !hasOperationalContent {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Caricamento pulizie…")
                        .font(.subheadline)
                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 280)
            } else {
                mainScrollContent
            }
        }
        .overlay(alignment: .top) {
            if dataStore.isRefreshingSupplementary {
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 4)
            }
        }
        .background(ThemeManager.shared.colorBackground.ignoresSafeArea())
        .navigationTitle("Controllo pulizia")
        .moduleScreenLoad(restaurantId: appState.activeRestaurantId) {
            guard let rid = appState.activeRestaurantId else { return }
            dataStore.reload(context: modelContext, restaurantId: rid)
            scheduleDeferredMaintenance(restaurantId: rid)
        }
        .sheet(isPresented: $showCriticalitySheet) {
            criticalitySheet
        }
        .sheet(isPresented: $showManageSheet) {
            manageSheet
        }
        .masterAuthCover(coordinator: masterAuth, master: users.first(where: { $0.role == .master }))
        .onDisappear {
            maintenanceTask?.cancel()
        }
    }

    private var mainScrollContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                ModuleScreenHeader(
                    title: "Controllo pulizia",
                    subtitle: "Piano sanificazione aree e attività con storico HACCP",
                    systemImage: "sparkles",
                    help: ModuleHelpLibrary.sidebar(.cleaningControl)
                )

                DashboardCardView(title: "Attività del giorno", subtitle: "Task da completare", help: ModuleHelpLibrary.sidebar(.cleaningControl)) {
                if !hasOperationalContent {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessun task di pulizia disponibile",
                        message: canManageCleaning ? "Crea aree e task dal pulsante Gestione." : "Attendi che il responsabile configuri aree e task.",
                        actionTitle: "Gestione aree/task"
                    )) {
                        masterAuth.request(permission: .manageCleaningConfiguration, permissions: permissions) {
                            showManageSheet = true
                        }
                    }
                } else {
                    VStack(spacing: 18) {
                        progressCard

                        // Bottoni gestione con icone
                        HStack(spacing: 10) {
                            Button {
                                masterAuth.request(permission: .manageCleaningConfiguration, permissions: permissions) {
                                    showManageSheet = true
                                }
                            } label: {
                                Label("Gestione aree/task", systemImage: "gearshape.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(ThemeManager.shared.colorPrimary)

                            Button(role: .destructive) {
                                masterAuth.request(permission: .clearCleaningHistory, permissions: permissions) {
                                    clearHistory()
                                }
                            } label: {
                                Label("Pulisci storico", systemImage: "trash.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }

                        Picker("Filtro", selection: $vm.selectedTab) {
                            ForEach(CleaningControlViewModel.Tab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch vm.selectedTab {
                        case .attivita:
                            CleaningDashboardView(
                                areas: scopedAreas,
                                runs: cleaningRuns,
                                templates: cleaningTemplates,
                                service: checklistService,
                                user: currentUser,
                                canExecute: canExecute,
                                onSync: syncCleaningSchedule
                            )
                        case .storico:
                            historyList
                        }
                    }
                }
                }
            }
            .padding(24)
        }
    }

    /// Indicatore circolare di progresso (anello) a destra del titolo.
    private var progressCard: some View {
        let completed = runBasedSummary.completed
        let total = runBasedSummary.total
        let pct = runBasedSummary.percentage

        return HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Completamento periodo")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                Text(total == 0
                    ? "Nessun task nel ciclo corrente"
                    : "\(completed) di \(total) task completati")
                    .font(.caption)
                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
            }

            Spacer(minLength: 8)

            CleaningCircularProgressView(
                progress: pct,
                label: total == 0 ? "—" : "\(Int(pct * 100))%",
                detail: total == 0 ? "0/0" : "\(completed)/\(total)"
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ThemeManager.shared.colorSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(ThemeManager.shared.colorDivider.opacity(0.8), lineWidth: 1)
                )
        )
    }

    private func cardList(_ cards: [CleaningTaskCard], emptyText: String) -> some View {
        Group {
            if cards.isEmpty {
                DashboardEmptyStateView(state: .init(title: "Nessun elemento", message: emptyText, actionTitle: nil))
            } else {
                VStack(spacing: 14) {
                    ForEach(areaNames(in: cards), id: \.self) { areaName in
                        let areaCards = cards.filter { $0.areaName == areaName }
                        VStack(alignment: .leading, spacing: 10) {
                            areaSectionHeader(areaName: areaName, completed: completedCount(in: areaCards), total: areaCards.count)
                            ForEach(areaCards) { card in
                                taskRow(card)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(ThemeManager.shared.colorSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(ThemeManager.shared.colorDivider, lineWidth: 1)
                                )
                        )
                    }
                }
            }
        }
    }

    private func areaSectionHeader(areaName: String, completed: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Area pulizia: \(areaName)", systemImage: "square.grid.2x2")
                    .font(.headline)
                    .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                Spacer()
                Text("\(completed)/\(total)")
                    .font(.caption.bold())
                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
            }
            ProgressView(value: total == 0 ? 0.0 : Double(completed) / Double(total))
                .tint(ThemeManager.shared.colorSuccess)

            if !areaChecklistHints(for: areaName).isEmpty {
                areaChecklistHintsView(areaName: areaName)
            }
        }
    }

    private func areaChecklistHints(for areaName: String) -> [ChecklistTemplate] {
        guard let rid = appState.activeRestaurantId else { return [] }
        let engine = PeriodicTaskEngine()
        return dataStore.checklistTemplates.filter { template in
            guard template.restaurantId == rid, template.isActive, !template.isCleaningBridge else { return false }
            guard template.areaTag?.localizedCaseInsensitiveCompare(areaName) == .orderedSame else { return false }
            guard let run = dataStore.checklistRuns.first(where: { $0.templateId == template.id && !$0.isArchived }) else {
                return true
            }
            let adapter = ChecklistRunPeriodicAdapter(
                run: run,
                frequency: template.frequency,
                category: template.category,
                areaTag: template.areaTag
            )
            return engine.isVisibleOnDashboard(adapter) && adapter.isOpen
        }
    }

    @ViewBuilder
    private func areaChecklistHintsView(areaName: String) -> some View {
        let hints = areaChecklistHints(for: areaName)
        VStack(alignment: .leading, spacing: 4) {
            Label("Anche in checklist per quest'area", systemImage: "checklist")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ThemeManager.shared.colorInfo)
            ForEach(hints) { template in
                Text("· \(template.title)")
                    .font(.caption2)
                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
            }
        }
        .padding(8)
        .background(ThemeManager.shared.colorInfo.opacity(0.08))
        .cornerRadius(8)
    }

    private func completedCount(in cards: [CleaningTaskCard]) -> Int {
        cards.filter(\.isCompleted).count
    }

    private func areaNames(in cards: [CleaningTaskCard]) -> [String] {
        Array(Set(cards.map(\.areaName))).sorted()
    }

    private func taskRow(_ card: CleaningTaskCard) -> some View {
        let outcomeBinding = Binding<CleaningTaskOutcome>(
            get: { card.record.outcome },
            set: { newValue in
                updateOutcome(for: card, outcome: newValue)
            }
        )
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.taskName).font(.subheadline.bold()).foregroundStyle(ThemeManager.shared.colorTextPrimary)
                    Text("Frequenza: \(card.frequency.label)").font(.caption2).foregroundStyle(ThemeManager.shared.colorTextSecondary)
                    Text(dueDescription(for: card))
                        .font(.caption2)
                        .foregroundStyle(card.isOverdue ? ThemeManager.shared.colorError : ThemeManager.shared.colorTextSecondary)
                    Text(periodDescription(for: card.record))
                        .font(.caption2)
                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                    Text(automaticTimestampDescription(for: card.record))
                        .font(.caption2)
                        .foregroundStyle(card.record.outcome == .daFare ? ThemeManager.shared.colorTextSecondary : ThemeManager.shared.colorInfo)
                }
                Spacer()
                if card.isOverdue {
                    HACCPBadge(title: "In ritardo", style: .warning, showIcon: false)
                }
            }

            Picker("Esito", selection: outcomeBinding) {
                Text("Pulito").tag(CleaningTaskOutcome.pulito)
                Text("Non pulito").tag(CleaningTaskOutcome.nonPulito)
                Text("N/A").tag(CleaningTaskOutcome.nonApplicabile)
            }
            .pickerStyle(.segmented)
            .disabled(!canExecute)

            if card.record.outcome != .daFare, canExecute {
                HStack {
                    Spacer()
                    Button("Riporta a da fare") {
                        updateOutcome(for: card, outcome: .daFare)
                    }
                    .buttonStyle(.bordered)
                    .tint(ThemeManager.shared.colorWarning)
                }
            }

            TextField("Note (opzionale)", text: Binding(
                get: { vm.noteDrafts[card.record.id] ?? card.record.notes ?? "" },
                set: { text in
                    vm.noteDrafts[card.record.id] = text
                    card.record.notes = text.isEmpty ? nil : text
                    card.record.updatedAt = Date()
                    if let user = currentUser {
                        card.record.updatedByUserId = user.id
                        card.record.updatedByNameSnapshot = user.name
                    }
                    try? modelContext.save()
                }
            ))
            .textFieldStyle(.roundedBorder)
            .disabled(!canExecute)

            if card.record.outcome == .nonPulito {
                Text("Per 'Non pulito' è obbligatoria un'azione correttiva.")
                    .font(.caption2)
                    .foregroundStyle(ThemeManager.shared.colorWarning)
            }
        }
        .padding(10)
        .background(ThemeManager.shared.colorSurface)
        .cornerRadius(10)
    }

    private var historyList: some View {
        let history = completedCleaningRuns
        return VStack(spacing: 14) {
            if history.isEmpty {
                DashboardEmptyStateView(state: .init(title: "Nessun elemento", message: "Nessun task di pulizia completato o scaduto nello storico.", actionTitle: nil))
            } else {
                ForEach(areaNames(for: history), id: \.self) { areaName in
                    let areaRuns = history.filter { areaTag(for: $0) == areaName }
                    VStack(alignment: .leading, spacing: 10) {
                        let completed = areaRuns.filter { $0.status == .completed }.count
                        areaSectionHeader(areaName: areaName, completed: completed, total: areaRuns.count)
                        ForEach(areaRuns) { run in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(taskTitle(for: run))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                                    Spacer()
                                    HACCPBadge(
                                        title: run.status.label,
                                        style: badgeStyle(for: run.status),
                                        showIcon: false
                                    )
                                }
                                Text("Esito: \(run.status.label) · \(run.completedByNameSnapshot ?? "—")")
                                    .font(.caption)
                                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                Text(periodDescription(for: run))
                                    .font(.caption2)
                                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                Text(automaticTimestampDescription(for: run))
                                    .font(.caption2)
                                    .foregroundStyle(ThemeManager.shared.colorInfo)
                                
                                let details = runDetails(for: run)
                                if !details.notes.isEmpty {
                                    Text("Note: \(details.notes)")
                                        .font(.caption2)
                                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                }
                                if !details.action.isEmpty {
                                    Text("Criticità: \(details.action)")
                                        .font(.caption2)
                                        .foregroundStyle(ThemeManager.shared.colorWarning)
                                }
                            }
                            .padding(10)
                            .background(ThemeManager.shared.colorSurface)
                            .cornerRadius(10)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(ThemeManager.shared.colorSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(ThemeManager.shared.colorDivider, lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    private func updateOutcome(for card: CleaningTaskCard, outcome: CleaningTaskOutcome) {
        guard let user = currentUser else { return }

        if outcome == .nonPulito {
            let note = (card.record.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let action = (card.record.correctiveAction ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !note.isEmpty, !action.isEmpty else {
                pendingCriticalityOriginalOutcome = card.record.outcome
                pendingCriticalityRecord = card.record
                showCriticalitySheet = true
                return
            }
            card.record.outcome = .nonPulito
            card.record.updatedAt = Date()
            card.record.updatedByUserId = user.id
            card.record.updatedByNameSnapshot = user.name
            pendingCriticalityRecord = card.record
            createOrUpdateCriticality(for: card.record, by: user, note: note, action: action)
        } else {
            card.record.outcome = outcome
            card.record.updatedAt = Date()
            card.record.updatedByUserId = user.id
            card.record.updatedByNameSnapshot = user.name
            resolveCriticalityIfNeeded(for: card.record, by: user)
        }
        try? modelContext.save()
        syncCleaningToChecklistEngine(taskId: card.id, record: card.record, outcome: card.record.outcome)
    }

    private func syncCleaningToChecklistEngine(taskId: UUID, record: CleaningRecord, outcome: CleaningTaskOutcome) {
        guard let user = currentUser,
              let task = scopedTasks.first(where: { $0.id == taskId }) else { return }
        try? cleaningBFF.syncOutcome(
            task: task,
            record: record,
            outcome: outcome,
            user: user,
            modelContext: modelContext
        )
    }

    private func createOrUpdateCriticality(for record: CleaningRecord, by user: LocalUser, note: String, action: String) {
        if let existing = scopedCriticalities.first(where: { $0.recordId == record.id && !$0.isResolved }) {
            existing.note = note
            existing.correctiveAction = action
        } else {
            let c = CleaningCriticality(
                restaurantId: record.restaurantId,
                recordId: record.id,
                areaName: record.areaName,
                taskName: record.taskName,
                note: note,
                correctiveAction: action,
                createdByUserId: user.id,
                createdByNameSnapshot: user.name
            )
            modelContext.insert(c)
        }
    }

    private func resolveCriticalityIfNeeded(for record: CleaningRecord, by user: LocalUser) {
        guard let open = scopedCriticalities.first(where: { $0.recordId == record.id && !$0.isResolved }) else { return }
        open.isResolved = true
        open.resolvedAt = Date()
        open.resolvedByUserId = user.id
        open.resolvedByNameSnapshot = user.name
    }

    private var criticalitySheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Criticità pulizia")
                    .font(.headline)
                Text("Inserisci nota e azione correttiva per completare.")
                    .font(.caption)
                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                TextField("Nota criticità", text: Binding(
                    get: { pendingCriticalityRecord?.notes ?? "" },
                    set: { pendingCriticalityRecord?.notes = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                TextField("Azione correttiva", text: Binding(
                    get: { pendingCriticalityRecord?.correctiveAction ?? "" },
                    set: { pendingCriticalityRecord?.correctiveAction = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                Button("Conferma criticità") {
                    guard let record = pendingCriticalityRecord, let user = currentUser else { return }
                    let note = (record.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let action = (record.correctiveAction ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !note.isEmpty, !action.isEmpty else { return }
                    record.outcome = .nonPulito
                    record.updatedAt = Date()
                    record.updatedByUserId = user.id
                    record.updatedByNameSnapshot = user.name
                    createOrUpdateCriticality(for: record, by: user, note: note, action: action)
                    try? modelContext.save()
                    HACCPLocalNotificationService.notifyCleaningCriticality(
                        areaName: record.areaName,
                        taskName: record.taskName,
                        recordId: record.id
                    )
                    KitchenProcessNotifications.postRecordsDidChange()
                    if let task = scopedTasks.first(where: { $0.id == record.taskId }) {
                        syncCleaningToChecklistEngine(taskId: task.id, record: record, outcome: .nonPulito)
                    }
                    showCriticalitySheet = false
                    pendingCriticalityRecord = nil
                    pendingCriticalityOriginalOutcome = nil
                }
                .buttonStyle(.borderedProminent)
                .tint(ThemeManager.shared.colorError)
                Button("Annulla") {
                    if let record = pendingCriticalityRecord, let previous = pendingCriticalityOriginalOutcome {
                        record.outcome = previous
                    }
                    showCriticalitySheet = false
                    pendingCriticalityRecord = nil
                    pendingCriticalityOriginalOutcome = nil
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            .padding()
        }
    }

    private func dueDescription(for card: CleaningTaskCard) -> String {
        let now = Date()
        if card.isOverdue {
            return "Scaduto il \(card.dueDate.formatted(date: .abbreviated, time: .shortened))"
        }
        if Calendar.current.isDate(card.dueDate, inSameDayAs: now) {
            return "Scadenza automatica: oggi alle \(card.dueDate.formatted(date: .omitted, time: .shortened))"
        }
        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
           Calendar.current.isDate(card.dueDate, inSameDayAs: tomorrow) {
            return "Scadenza automatica: domani alle \(card.dueDate.formatted(date: .omitted, time: .shortened))"
        }
        return "Scadenza automatica: \(card.dueDate.formatted(date: .abbreviated, time: .shortened))"
    }

    private func periodDescription(for record: CleaningRecord) -> String {
        let start = record.periodStart.formatted(date: .abbreviated, time: .shortened)
        let end = record.periodEnd.formatted(date: .abbreviated, time: .shortened)
        return "Periodo automatico: \(start) → \(end)"
    }

    private func automaticTimestampDescription(for record: CleaningRecord) -> String {
        if record.outcome == .daFare {
            return "Creato automaticamente: \(record.createdAt.formatted(date: .abbreviated, time: .shortened))"
        }
        return "Data/ora pulizia automatica: \(record.updatedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private var manageSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Aree e task")
                        .font(.headline)
                    HStack {
                        TextField("Nuova area", text: $newAreaName)
                            .textFieldStyle(.roundedBorder)
                        Button("Aggiungi") { addArea() }
                            .buttonStyle(.bordered)
                    }
                    ForEach(scopedAreas) { area in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(area.name).foregroundStyle(ThemeManager.shared.colorTextPrimary)
                                Spacer()
                                Button("Elimina", role: .destructive) { deleteArea(area) }
                                    .buttonStyle(.bordered)
                            }
                            let areaTasks = scopedTasks.filter { $0.areaId == area.id }
                            ForEach(areaTasks) { task in
                                HStack {
                                    Text("• \(task.title) · \(task.frequency.label)")
                                        .font(.caption)
                                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                    Spacer()
                                    Button("Elimina", role: .destructive) { deleteTask(task) }
                                        .buttonStyle(.bordered)
                                }
                            }
                            HStack {
                                TextField("Nuovo task", text: Binding(
                                    get: { selectedAreaIdForNewTask == area.id ? newTaskName : "" },
                                    set: {
                                        selectedAreaIdForNewTask = area.id
                                        newTaskName = $0
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                                Picker("Freq", selection: $newTaskFrequency) {
                                    ForEach(CleaningTaskFrequency.allCases, id: \.self) { f in
                                        Text(f.label).tag(f)
                                    }
                                }
                                .pickerStyle(.menu)
                                if newTaskFrequency == .personalizzato {
                                    TextField("gg", text: $newTaskCustomDays)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 60)
                                }
                                Button("Aggiungi") { addTask(to: area) }
                                    .buttonStyle(.bordered)
                            }
                        }
                        .padding(10)
                        .background(ThemeManager.shared.colorSurface)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .background(ThemeManager.shared.colorBackground.ignoresSafeArea())
        }
    }

    private func addArea() {
        guard canUseCleaningConfig, let rid = appState.activeRestaurantId, let user = currentUser else { return }
        let name = newAreaName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let key = CleaningAreaGrouping.normalizeName(name)
        guard !scopedAreas.contains(where: { CleaningAreaGrouping.normalizeName($0.name) == key }) else {
            newAreaName = ""
            return
        }
        let area = CleaningArea(
            restaurantId: rid,
            name: name,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name
        )
        modelContext.insert(area)
        newAreaName = ""
        try? modelContext.save()
    }

    private func addTask(to area: CleaningArea) {
        guard canUseCleaningConfig, let rid = appState.activeRestaurantId, let user = currentUser else { return }
        let title = newTaskName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let days = Int(newTaskCustomDays)
        let task = CleaningTask(
            restaurantId: rid,
            areaId: area.id,
            areaNameSnapshot: area.name,
            title: title,
            frequency: newTaskFrequency,
            customIntervalDays: newTaskFrequency == .personalizzato ? max(days ?? 1, 1) : nil,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name
        )
        modelContext.insert(task)
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "it_IT")
        cal.timeZone = .current
        _ = vm.service.ensureRecordForCurrentPeriod(
            task: task,
            restaurantId: rid,
            user: user,
            existingRecords: scopedRecords,
            calendar: cal,
            modelContext: modelContext
        )
        newTaskName = ""
        newTaskCustomDays = ""
        try? modelContext.save()
    }

    private func deleteArea(_ area: CleaningArea) {
        guard canUseCleaningConfig else { return }
        for task in scopedTasks where task.areaId == area.id {
            modelContext.delete(task)
        }
        modelContext.delete(area)
        try? modelContext.save()
    }

    private func deleteTask(_ task: CleaningTask) {
        guard canUseCleaningConfig else { return }
        modelContext.delete(task)
        try? modelContext.save()
    }

    private func clearHistory() {
        for record in scopedRecords { modelContext.delete(record) }
        for c in scopedCriticalities { modelContext.delete(c) }
        try? modelContext.save()
        ensureRecordsForCurrentPeriod()
        try? modelContext.save()
    }

    private func scheduleDeferredMaintenance(restaurantId: UUID) {
        maintenanceTask?.cancel()
        maintenanceTask = Task(priority: .utility) { @MainActor in
            await MainThreadYield.awaitNavigationSettled {
                ModuleNavigationCoordinator.shared.generation
            }
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, let user = currentUser else { return }

            var didMutateStore = false

            if RestaurantModuleBootstrap.shared.claimOnce(
                restaurantId: restaurantId,
                module: "cleaning-dedupe-areas"
            ) {
                let removedAreas = CleaningAreaGrouping.deduplicateInStore(
                    restaurantId: restaurantId,
                    areas: dataStore.areas,
                    tasks: dataStore.tasks,
                    modelContext: modelContext
                )
                let removedTasks = CleaningAreaGrouping.deduplicateTasksInStore(
                    restaurantId: restaurantId,
                    tasks: dataStore.tasks,
                    modelContext: modelContext
                )
                didMutateStore = removedAreas > 0 || removedTasks > 0
            }

            if scopedTasks.isEmpty, !scopedAreas.isEmpty {
                await vm.service.backfillSeedTasksIfNeeded(
                    restaurantId: restaurantId,
                    areas: scopedAreas,
                    existingTasks: scopedTasks,
                    user: user,
                    modelContext: modelContext
                )
                didMutateStore = true
            }

            if didMutateStore {
                dataStore.reload(context: modelContext, restaurantId: restaurantId, force: true)
                guard !Task.isCancelled else { return }
            }

            guard RestaurantModuleBootstrap.shared.claimOnce(
                restaurantId: restaurantId,
                module: "cleaning-period-sync"
            ) else { return }

            await ensureRecordsForCurrentPeriodAsync()
            guard !Task.isCancelled else { return }
            dataStore.reload(context: modelContext, restaurantId: restaurantId, force: true)
        }
    }

    private func ensureRecordsForCurrentPeriodAsync() async {
        guard let rid = appState.activeRestaurantId, let user = currentUser else { return }
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "it_IT")
        cal.timeZone = .current
        vm.service.closeStaleCleaningRecords(
            restaurantId: rid,
            tasks: scopedTasks,
            records: scopedRecords,
            calendar: cal,
            modelContext: modelContext
        )
        await MainThreadYield.betweenFetchPhases()

        cleaningBFF.ensureBridgeTemplates(
            restaurantId: rid,
            tasks: scopedTasks,
            user: user,
            modelContext: modelContext
        )
        await MainThreadYield.betweenFetchPhases()

        checklistService.syncScheduledRuns(
            restaurantId: rid,
            user: user,
            modelContext: modelContext,
            onlyCleaningBridge: true
        )
        await MainThreadYield.betweenFetchPhases()

        let activeTasks = scopedTasks.filter { $0.restaurantId == rid && $0.isActive }
        for (index, task) in activeTasks.enumerated() {
            if index > 0, index % 4 == 0 {
                await MainThreadYield.betweenFetchPhases()
                guard !Task.isCancelled else { return }
            }
            _ = vm.service.ensureRecordForCurrentPeriod(
                task: task,
                restaurantId: rid,
                user: user,
                existingRecords: scopedRecords,
                calendar: cal,
                modelContext: modelContext
            )
        }
        modelContext.saveSafely(operation: "cleaning-period-records")
    }

    private func ensureRecordsForCurrentPeriod() {
        Task { @MainActor in
            await ensureRecordsForCurrentPeriodAsync()
        }
    }

    private func syncCleaningSchedule() {
        guard let rid = appState.activeRestaurantId, let user = currentUser else { return }
        cleaningBFF.ensureBridgeTemplates(
            restaurantId: rid,
            tasks: scopedTasks,
            user: user,
            modelContext: modelContext
        )
        checklistService.syncScheduledRuns(
            restaurantId: rid,
            user: user,
            modelContext: modelContext,
            onlyCleaningBridge: true
        )
        dataStore.reload(context: modelContext, restaurantId: rid, force: true)
    }
}

// MARK: - Anello progresso compatto

private struct CleaningCircularProgressView: View {
    let progress: Double
    let label: String
    let detail: String

    @Environment(\.theme) private var theme

    private var clamped: Double {
        min(1, max(0, progress))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.colorDivider.opacity(0.55), lineWidth: 7)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    theme.colorPrimary,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.35), value: clamped)

            VStack(spacing: 1) {
                Text(label)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.colorTextPrimary)
                Text(detail)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.colorTextSecondary)
            }
        }
        .frame(width: 64, height: 64)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Completamento \(label), \(detail)")
    }
}
