import SwiftUI
import SwiftData

struct ChecklistRunView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [LocalUser]
    @Query private var itemResults: [ChecklistItemResult]
    @Query private var templates: [ChecklistTemplate]
    @Query private var itemTemplates: [ChecklistItemTemplate]

    let run: ChecklistRun
    let service: ChecklistService
    var onOpenCriticalities: (() -> Void)? = nil
    @StateObject private var vm = ChecklistRunViewModel()

    init(
        run: ChecklistRun,
        service: ChecklistService,
        onOpenCriticalities: (() -> Void)? = nil
    ) {
        self.run = run
        self.service = service
        self.onOpenCriticalities = onOpenCriticalities

        let runId = run.id
        let templateId = run.templateId
        _itemResults = Query(
            filter: #Predicate<ChecklistItemResult> { $0.checklistRunId == runId },
            sort: [SortDescriptor(\ChecklistItemResult.orderIndex)]
        )
        _templates = Query(
            filter: #Predicate<ChecklistTemplate> { $0.id == templateId }
        )
        _itemTemplates = Query(
            filter: #Predicate<ChecklistItemTemplate> { $0.checklistTemplateId == templateId },
            sort: [SortDescriptor(\ChecklistItemTemplate.orderIndex)]
        )
    }

    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }

    private var template: ChecklistTemplate? {
        templates.first { $0.id == run.templateId }
    }

    private var scopedResults: [ChecklistItemResult] {
        itemResults
            .filter { $0.checklistRunId == run.id }
            .sorted(by: { $0.orderIndex < $1.orderIndex })
    }

    private var summary: ChecklistProgressSummary {
        ChecklistProgressSummary.from(run: run, results: scopedResults)
    }

    private var showsBulkPass: Bool {
        guard let template, template.supportsBulkPass, scopedResults.count >= 2 else { return false }
        return run.progressPercentage < 100
    }

    private var bulkPassLabel: String {
        template?.bulkPassTitle ?? "Tutto conforme — segna tutte le voci OK"
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing.sectionSpacing) {
                progressCard

                if showsBulkPass {
                    bulkPassCard
                }

                if summary.hasFailures, run.progressPercentage >= 100 {
                    criticalitiesBanner
                }

                DashboardCardView(
                    title: "Attività da verificare",
                    subtitle: bulkPassHint
                ) {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(scopedResults.enumerated()), id: \.element.id) { index, result in
                            ChecklistRunItemCard(
                                index: index + 1,
                                result: result,
                                requiresNoteIfFailed: requiresNote(for: result),
                                onSave: { value, note in
                                    save(result: result, value: value, note: note)
                                }
                            )
                        }
                    }
                }
            }
            .padding(theme.spacing.screenPadding)
        }
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle(run.templateTitleSnapshot)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Chiudi") { dismiss() }
            }
        }
        .alert("Checklist", isPresented: Binding(get: { vm.completionError != nil }, set: { _ in vm.completionError = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.completionError ?? "")
        }
        .onChange(of: run.progressPercentage) { _, progress in
            guard progress >= 100 else { return }
            HapticManager.shared.notification(.success)
        }
    }

    private var bulkPassHint: String {
        if showsBulkPass {
            return "Oppure deseleziona solo le voci NON OK"
        }
        return "\(summary.completed) di \(summary.total) completate"
    }

    private var bulkPassCard: some View {
        DashboardCardView(title: "Compilazione rapida", subtitle: "Un tap se tutto è conforme") {
            PrimaryButton(title: bulkPassLabel, icon: "checkmark.circle.fill") {
                bulkPassAll()
            }
        }
    }

    private var criticalitiesBanner: some View {
        DashboardCardView(
            title: "Criticità da gestire",
            subtitle: "Registra le azioni correttive per chiudere le segnalazioni HACCP"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Label(
                    "\(summary.failedCount) attività segnate NON OK",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(theme.typography.subheadline)
                .foregroundStyle(theme.colorError)

                if let onOpenCriticalities {
                    PrimaryButton(title: "Vai a Criticità", icon: "wrench.and.screwdriver.fill") {
                        dismiss()
                        onOpenCriticalities()
                    }
                } else {
                    Text("Apri il tab Criticità per registrare cosa è stato fatto.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }
        }
    }

    private func requiresNote(for result: ChecklistItemResult) -> Bool {
        itemTemplates.first { $0.id == result.itemTemplateId }?.requiresNoteIfFailed ?? true
    }

    private var progressCard: some View {
        DashboardCardView(title: "Avanzamento", subtitle: statusSubtitle) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(Int(run.progressPercentage))%")
                        .font(theme.typography.title2.weight(.bold))
                        .foregroundStyle(theme.colorTextPrimary)
                    Spacer()
                    HACCPBadge(title: run.status.label, style: run.status.badgeStyle, showIcon: false)
                }
                ProgressView(value: run.progressPercentage, total: 100)
                    .tint(progressTint)
                if let dueAt = run.dueAt {
                    Label(
                        "Scadenza \(dueAt.formatted(date: .abbreviated, time: .shortened))",
                        systemImage: "clock"
                    )
                    .font(theme.typography.caption)
                    .foregroundStyle(run.status == .overdue ? theme.colorWarning : theme.colorTextSecondary)
                }
                if let frequency = template?.frequency, frequency != .daily {
                    Label(frequency.label, systemImage: frequency.systemImage)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
                if summary.hasFailures {
                    Label("Sono presenti attività NON OK", systemImage: "exclamationmark.triangle.fill")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorError)
                }
            }
        }
    }

    private var statusSubtitle: String {
        if run.progressPercentage >= 100 {
            return summary.hasFailures ? "Completata con criticità" : "Completata"
        }
        return "Segna ogni voce — salvataggio automatico"
    }

    private var progressTint: Color {
        if summary.hasFailures { return theme.colorError }
        if run.progressPercentage >= 100 { return theme.colorSuccess }
        if run.progressPercentage >= 50 { return theme.colorWarning }
        return theme.colorInfo
    }

    private func bulkPassAll() {
        guard let currentUser else { return }
        do {
            try service.markAllItemsPass(
                run: run,
                user: currentUser,
                restaurantId: run.restaurantId,
                modelContext: modelContext
            )
            HapticManager.shared.notification(.success)
        } catch {
            vm.completionError = "Compilazione rapida non riuscita."
        }
    }

    private func save(result: ChecklistItemResult, value: ChecklistItemResultValue, note: String?) {
        guard let currentUser else { return }
        do {
            try service.updateItemResult(
                itemResult: result,
                result: value,
                note: note,
                user: currentUser,
                run: run,
                restaurantId: run.restaurantId,
                modelContext: modelContext
            )
        } catch let error as ChecklistServiceError {
            vm.completionError = error.localizedDescription
        } catch {
            vm.completionError = "Salvataggio non riuscito."
        }
    }
}

struct ChecklistRunItemCard: View {
    private static let quickNotes = [
        "Pulito e sanificato",
        "Prodotto ritirato",
        "Riparato / ripristinato",
        "Segnalato al responsabile"
    ]

    let index: Int
    let result: ChecklistItemResult
    let requiresNoteIfFailed: Bool
    let onSave: (ChecklistItemResultValue, String?) -> Void

    @Environment(\.theme) private var theme
    @State private var selectedValue: ChecklistItemResultValue = .pending
    @State private var note: String = ""
    @State private var initialized = false

    private var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var needsNoteBeforeSave: Bool {
        selectedValue == .fail && requiresNoteIfFailed && trimmedNote.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(index)")
                    .font(theme.typography.caption.weight(.bold))
                    .foregroundStyle(theme.colorTextOnPrimary)
                    .frame(width: 26, height: 26)
                    .background(theme.colorPrimary.opacity(0.85))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(result.titleSnapshot)
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colorTextPrimary)
                    HACCPBadge(title: displayedBadge.label, style: displayedBadge.badgeStyle, showIcon: true)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                outcomeButton(.pass, title: "OK", tint: theme.colorSuccess)
                outcomeButton(.fail, title: "NON OK", tint: theme.colorError)
                outcomeButton(.notApplicable, title: "N/A", tint: theme.colorTextSecondary)
            }

            if selectedValue == .fail {
                VStack(alignment: .leading, spacing: 8) {
                    Text(requiresNoteIfFailed ? "Descrivi la criticità (obbligatoria)" : "Descrivi la criticità (consigliata)")
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(requiresNoteIfFailed ? theme.colorError : theme.colorTextSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.quickNotes, id: \.self) { quickNote in
                                Button {
                                    note = quickNote
                                    HapticManager.shared.trigger(.light)
                                    persistIfReady()
                                } label: {
                                    Text(quickNote)
                                        .font(theme.typography.caption2.weight(.medium))
                                        .foregroundStyle(theme.colorTextPrimary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(theme.colorError.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    TextField("Es. temperatura fuori range, prodotto danneggiato…", text: $note, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                }
            } else {
                TextField("Nota opzionale", text: $note)
                    .textFieldStyle(.roundedBorder)
            }

            if needsNoteBeforeSave {
                Text("Inserisci una nota per registrare la criticità")
                    .font(theme.typography.caption2)
                    .foregroundStyle(theme.colorWarning)
            } else if selectedValue == .fail, result.result == .fail {
                Label("Criticità registrata — gestisci dal tab Criticità", systemImage: "exclamationmark.triangle.fill")
                    .font(theme.typography.caption2)
                    .foregroundStyle(theme.colorError)
            } else {
                Text(saveStatusText)
                    .font(theme.typography.caption2)
                    .foregroundStyle(theme.colorTextSecondary)
            }
        }
        .padding(14)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .stroke(borderColor.opacity(0.7), lineWidth: needsNoteBeforeSave ? 2 : 1)
        )
        .onAppear {
            selectedValue = result.result
            note = result.note ?? ""
            initialized = true
        }
        .onChange(of: selectedValue) { _, newValue in
            guard initialized else { return }
            if newValue == .fail, requiresNoteIfFailed, trimmedNote.isEmpty {
                return
            }
            persistIfReady()
        }
        .onChange(of: note) { _, _ in
            guard initialized else { return }
            persistIfReady()
        }
    }

    private var displayedBadge: ChecklistItemResultValue {
        if needsNoteBeforeSave, result.result != .fail {
            return .pending
        }
        return selectedValue
    }

    private var saveStatusText: String {
        if selectedValue == .pending {
            return "Seleziona esito per salvare"
        }
        return "Salvataggio automatico"
    }

    private func persistIfReady() {
        if selectedValue == .fail, requiresNoteIfFailed, trimmedNote.isEmpty {
            return
        }
        onSave(selectedValue, trimmedNote.isEmpty ? nil : trimmedNote)
    }

    private var borderColor: Color {
        if needsNoteBeforeSave { return theme.colorWarning }
        switch selectedValue {
        case .fail: return theme.colorError
        case .pass: return theme.colorSuccess
        case .notApplicable: return theme.colorDivider
        case .pending: return theme.colorDivider
        }
    }

    private func outcomeButton(_ value: ChecklistItemResultValue, title: String, tint: Color) -> some View {
        Button {
            selectedValue = value
            HapticManager.shared.trigger(.light)
        } label: {
            Text(title)
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(selectedValue == value ? theme.colorTextOnPrimary : tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selectedValue == value ? tint : tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
