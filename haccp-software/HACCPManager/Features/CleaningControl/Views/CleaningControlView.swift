import SwiftUI
import SwiftData

struct CleaningControlView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var areas: [CleaningArea]
    @Query private var tasks: [CleaningTask]
    @Query private var records: [CleaningRecord]
    @Query private var criticalities: [CleaningCriticality]
    @StateObject private var vm = CleaningControlViewModel()
    @State private var pendingCriticalityRecord: CleaningRecord?
    @State private var showCriticalitySheet = false
    @State private var pendingCriticalityOriginalOutcome: CleaningTaskOutcome?
    @State private var showMasterManage = false
    @State private var showManageSheet = false
    @State private var showMasterClearHistory = false
    @State private var selectedAreaIdForNewTask: UUID?
    @State private var newAreaName: String = ""
    @State private var newTaskName: String = ""
    @State private var newTaskFrequency: CleaningTaskFrequency = .giornaliero
    @State private var newTaskCustomDays: String = ""

    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }

    private var isMaster: Bool {
        currentUser?.role == .master
    }

    private var scopedAreas: [CleaningArea] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return areas
            .filter { $0.restaurantId == rid }
            .sorted { $0.name < $1.name }
    }

    private var scopedTasks: [CleaningTask] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return tasks.filter { $0.restaurantId == rid }
    }

    private var scopedRecords: [CleaningRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return records.filter { $0.restaurantId == rid }
    }

    private var scopedCriticalities: [CleaningCriticality] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return criticalities.filter { $0.restaurantId == rid }
    }

    private var grouped: (todo: [CleaningTaskCard], overdue: [CleaningTaskCard], completed: [CleaningTaskCard], history: [CleaningRecord]) {
        guard let rid = appState.activeRestaurantId else { return ([], [], [], []) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "it_IT")
        calendar.timeZone = .current
        return vm.service.buildTaskCards(
            restaurantId: rid,
            tasks: scopedTasks,
            records: scopedRecords,
            criticalities: scopedCriticalities,
            calendar: calendar
        )
    }

    private var summary: CleaningSummary {
        vm.service.summary(for: grouped.todo + grouped.overdue + grouped.completed)
    }

    var body: some View {
        ScrollView {
            DashboardCardView(title: "Controllo pulizia") {
                if scopedTasks.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessun task di pulizia disponibile",
                        message: isMaster ? "Crea aree e task dal pulsante Gestione." : "Attendi che il MASTER configuri aree e task.",
                        actionTitle: isMaster ? "Gestione" : nil
                    ))
                } else {
                    VStack(spacing: 14) {
                        progressCard
                        if isMaster {
                            HStack(spacing: 8) {
                                Button("Gestione aree/task") { showMasterManage = true }
                                    .buttonStyle(.bordered)
                                    .tint(.white)
                                Button("Pulisci storico", role: .destructive) { showMasterClearHistory = true }
                                    .buttonStyle(.bordered)
                            }
                        }
                        Picker("Filtro", selection: $vm.selectedTab) {
                            ForEach(CleaningControlViewModel.Tab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch vm.selectedTab {
                        case .oggi:
                            cardList(grouped.todo, emptyText: "Nessun task da fare oggi.")
                        case .ritardo:
                            cardList(grouped.overdue, emptyText: "Nessun task in ritardo.")
                        case .completate:
                            cardList(grouped.completed, emptyText: "Nessun task completato.")
                        case .storico:
                            historyList
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Controllo pulizia")
        .onAppear {
            bootstrapTemplatesIfNeeded()
        }
        .sheet(isPresented: $showCriticalitySheet) {
            criticalitySheet
        }
        .sheet(isPresented: $showManageSheet) {
            manageSheet
        }
        .fullScreenCover(isPresented: $showMasterManage) {
            masterManageOverlay
        }
        .fullScreenCover(isPresented: $showMasterClearHistory) {
            masterClearOverlay
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Completamento periodo corrente")
                .font(.subheadline.bold())
                .foregroundColor(.white.opacity(0.9))
            Text("\(summary.completed) / \(summary.total) task · \(Int(summary.percentage * 100))%")
                .font(.caption)
                .foregroundColor(.gray)
            ProgressView(value: summary.percentage)
                .tint(.green)
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }

    private func cardList(_ cards: [CleaningTaskCard], emptyText: String) -> some View {
        Group {
            if cards.isEmpty {
                DashboardEmptyStateView(state: .init(title: "Nessun elemento", message: emptyText, actionTitle: nil))
            } else {
                VStack(spacing: 10) {
                    ForEach(cards) { card in
                        taskRow(card)
                    }
                }
            }
        }
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
                    Text(card.areaName).font(.subheadline.bold()).foregroundColor(.white)
                    Text(card.taskName).font(.caption).foregroundColor(.white.opacity(0.9))
                    Text("Frequenza: \(card.frequency.label)").font(.caption2).foregroundColor(.gray)
                    Text(dueDescription(for: card))
                        .font(.caption2)
                        .foregroundColor(card.isOverdue ? .red : .gray)
                }
                Spacer()
                if card.isOverdue {
                    Text("IN RITARDO").font(.caption2.bold()).foregroundColor(.red)
                }
            }

            Picker("Esito", selection: outcomeBinding) {
                Text("Pulito").tag(CleaningTaskOutcome.pulito)
                Text("Non pulito").tag(CleaningTaskOutcome.nonPulito)
                Text("N/A").tag(CleaningTaskOutcome.nonApplicabile)
            }
            .pickerStyle(.segmented)

            if card.record.outcome != .daFare {
                HStack {
                    Spacer()
                    Button("Riporta a da fare") {
                        updateOutcome(for: card, outcome: .daFare)
                    }
                    .buttonStyle(.bordered)
                    .tint(.yellow)
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

            if card.record.outcome == .nonPulito {
                Text("Per 'Non pulito' è obbligatoria un'azione correttiva.")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }

    private var historyList: some View {
        VStack(spacing: 10) {
            ForEach(grouped.history.prefix(200)) { record in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(record.areaName) · \(record.taskName)")
                        .foregroundColor(.white)
                    Text("\(record.outcome.label) · \(record.updatedByNameSnapshot) · \(record.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.gray)
                    if let note = record.notes, !note.isEmpty {
                        Text("Note: \(note)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    if let action = record.correctiveAction, !action.isEmpty {
                        Text("Azione correttiva: \(action)")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
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
                    .foregroundColor(.gray)
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
                    showCriticalitySheet = false
                    pendingCriticalityRecord = nil
                    pendingCriticalityOriginalOutcome = nil
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
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
            return "Scaduto il \(card.dueDate.formatted(date: .abbreviated, time: .omitted))"
        }
        if Calendar.current.isDate(card.dueDate, inSameDayAs: now) {
            return "Scadenza: oggi"
        }
        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
           Calendar.current.isDate(card.dueDate, inSameDayAs: tomorrow) {
            return "Scadenza: domani"
        }
        return "Scadenza: \(card.dueDate.formatted(date: .abbreviated, time: .omitted))"
    }

    @ViewBuilder
    private var masterManageOverlay: some View {
        if let master = users.first(where: { $0.role == .master }) {
            MasterAuthOverlay(
                master: master,
                operation: .manageCleaningTasks,
                onAuthorized: {
                    showMasterManage = false
                    showManageSheet = true
                },
                onCancel: { showMasterManage = false }
            ) {
                EmptyView()
            }
        }
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
                                Text(area.name).foregroundColor(.white)
                                Spacer()
                                Button("Elimina", role: .destructive) { deleteArea(area) }
                                    .buttonStyle(.bordered)
                            }
                            let areaTasks = scopedTasks.filter { $0.areaId == area.id }
                            ForEach(areaTasks) { task in
                                HStack {
                                    Text("• \(task.title) · \(task.frequency.label)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
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
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        }
    }

    @ViewBuilder
    private var masterClearOverlay: some View {
        if let master = users.first(where: { $0.role == .master }) {
            MasterAuthOverlay(
                master: master,
                operation: .clearCleaningHistory,
                onAuthorized: {
                    clearHistory()
                    showMasterClearHistory = false
                },
                onCancel: { showMasterClearHistory = false }
            ) { EmptyView() }
        }
    }

    private func addArea() {
        guard isMaster, let rid = appState.activeRestaurantId, let user = currentUser else { return }
        let name = newAreaName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
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
        guard isMaster, let rid = appState.activeRestaurantId, let user = currentUser else { return }
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
        ensureRecordsForCurrentPeriod()
        newTaskName = ""
        newTaskCustomDays = ""
        try? modelContext.save()
    }

    private func deleteArea(_ area: CleaningArea) {
        guard isMaster else { return }
        for task in scopedTasks where task.areaId == area.id {
            modelContext.delete(task)
        }
        modelContext.delete(area)
        try? modelContext.save()
    }

    private func deleteTask(_ task: CleaningTask) {
        guard isMaster else { return }
        modelContext.delete(task)
        try? modelContext.save()
    }

    private func clearHistory() {
        guard isMaster else { return }
        for record in scopedRecords { modelContext.delete(record) }
        for c in scopedCriticalities { modelContext.delete(c) }
        ensureRecordsForCurrentPeriod()
        try? modelContext.save()
    }

    private func bootstrapTemplatesIfNeeded() {
        guard let rid = appState.activeRestaurantId, let user = currentUser else { return }
        vm.service.ensureInitialTemplates(
            restaurantId: rid,
            user: user,
            existingAreas: scopedAreas,
            existingTasks: scopedTasks,
            modelContext: modelContext
        )
        ensureRecordsForCurrentPeriod()
    }

    private func ensureRecordsForCurrentPeriod() {
        guard let rid = appState.activeRestaurantId, let user = currentUser else { return }
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "it_IT")
        cal.timeZone = .current
        for task in scopedTasks where task.restaurantId == rid && task.isActive {
            _ = vm.service.ensureRecordForCurrentPeriod(
                task: task,
                restaurantId: rid,
                user: user,
                existingRecords: scopedRecords,
                calendar: cal,
                modelContext: modelContext
            )
        }
        try? modelContext.save()
    }
}
