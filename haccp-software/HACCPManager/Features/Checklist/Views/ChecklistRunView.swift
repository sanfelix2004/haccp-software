import SwiftUI
import SwiftData

struct ChecklistRunView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [LocalUser]
    @Query private var itemResults: [ChecklistItemResult]

    let run: ChecklistRun
    let service: ChecklistService
    @StateObject private var vm = ChecklistRunViewModel()

    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }

    private var scopedResults: [ChecklistItemResult] {
        itemResults
            .filter { $0.checklistRunId == run.id }
            .sorted(by: { $0.orderIndex < $1.orderIndex })
    }

    private var summary: ChecklistProgressSummary {
        ChecklistProgressSummary.from(run: run, results: scopedResults)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing.sectionSpacing) {
                progressCard

                DashboardCardView(
                    title: "Attività da verificare",
                    subtitle: "\(summary.completed) di \(summary.total) completate"
                ) {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(scopedResults.enumerated()), id: \.element.id) { index, result in
                            ChecklistRunItemCard(
                                index: index + 1,
                                result: result,
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
        return "Segna ogni voce e salva"
    }

    private var progressTint: Color {
        if summary.hasFailures { return theme.colorError }
        if run.progressPercentage >= 100 { return theme.colorSuccess }
        if run.progressPercentage >= 50 { return theme.colorWarning }
        return theme.colorInfo
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
        } catch {
            vm.completionError = "Salvataggio non riuscito."
        }
    }
}

struct ChecklistRunItemCard: View {
    let index: Int
    let result: ChecklistItemResult
    let onSave: (ChecklistItemResultValue, String?) -> Void

    @Environment(\.theme) private var theme
    @State private var selectedValue: ChecklistItemResultValue = .pending
    @State private var note: String = ""
    @State private var initialized = false

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
                    HACCPBadge(title: selectedValue.label, style: selectedValue.badgeStyle, showIcon: true)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                outcomeButton(.pass, title: "OK", tint: theme.colorSuccess)
                outcomeButton(.fail, title: "NON OK", tint: theme.colorError)
                outcomeButton(.notApplicable, title: "N/A", tint: theme.colorTextSecondary)
            }

            if selectedValue == .fail {
                TextField("Nota criticità (consigliata)", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            } else {
                TextField("Nota opzionale", text: $note)
                    .textFieldStyle(.roundedBorder)
            }

            Text("Salvataggio automatico")
                .font(theme.typography.caption2)
                .foregroundStyle(theme.colorTextSecondary)
        }
        .padding(14)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .stroke(borderColor.opacity(0.7), lineWidth: 1)
        )
        .onAppear {
            selectedValue = result.result
            note = result.note ?? ""
            initialized = true
        }
        .onChange(of: selectedValue) { _, _ in
            guard initialized else { return }
            onSave(selectedValue, note.isEmpty ? nil : note)
        }
        .onChange(of: note) { _, _ in
            guard initialized else { return }
            onSave(selectedValue, note.isEmpty ? nil : note)
        }
    }

    private var borderColor: Color {
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
