import SwiftUI
import SwiftData

struct SchedulingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    @Query private var tasks: [ScheduledTask]
    @Query private var users: [LocalUser]
    @StateObject private var vm = SchedulingViewModel()

    @State private var showNewSheet = false
    @State private var taskPendingDelete: ScheduledTask?
    @State private var errorMessage: String?

    private var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }

    private var scopedTasks: [ScheduledTask] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return tasks.filter { $0.restaurantId == rid }
    }

    private var overdueTasks: [ScheduledTask] {
        scopedTasks
            .filter { vm.service.isOverdue($0) }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
    }

    private var todoTasks: [ScheduledTask] {
        scopedTasks
            .filter { !$0.isCompleted && !vm.service.isOverdue($0) }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
    }

    private var doneTasks: [ScheduledTask] {
        scopedTasks
            .filter { $0.isCompleted }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        Group {
            if appState.activeRestaurantId == nil {
                DashboardEmptyStateView(state: .init(
                    title: "Seleziona un'attività",
                    message: "Le attività programmate sono legate al ristorante attivo.",
                    actionTitle: nil
                ))
                .padding(24)
            } else {
                mainScroll
            }
        }
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle("Programmazione")
        .sheet(isPresented: $showNewSheet) {
            if let rid = appState.activeRestaurantId, let user = currentUser {
                ScheduledTaskEditorSheet(
                    restaurantId: rid,
                    user: user,
                    onSaved: { showNewSheet = false },
                    onCancel: { showNewSheet = false }
                )
            }
        }
        .alert("Programmazione", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            "Eliminare l'attività?",
            isPresented: Binding(
                get: { taskPendingDelete != nil },
                set: { if !$0 { taskPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Elimina", role: .destructive) {
                if let task = taskPendingDelete { delete(task) }
                taskPendingDelete = nil
            }
            Button("Annulla", role: .cancel) { taskPendingDelete = nil }
        }
    }

    private var mainScroll: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing.sectionSpacing) {
                statsRow

                PrimaryButton(title: "Nuova attività", icon: "plus.circle.fill") {
                    showNewSheet = true
                }

                if scopedTasks.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessuna attività programmata",
                        message: "Crea attività ricorrenti (giornaliere, settimanali, mensili) per non dimenticare i controlli HACCP.",
                        actionTitle: "Nuova attività"
                    )) {
                        showNewSheet = true
                    }
                } else {
                    if !overdueTasks.isEmpty {
                        DashboardCardView(title: "In ritardo", subtitle: "\(overdueTasks.count) da completare subito") {
                            taskList(overdueTasks)
                        }
                    }
                    if !todoTasks.isEmpty {
                        DashboardCardView(title: "Da fare", subtitle: "\(todoTasks.count) attività in programma") {
                            taskList(todoTasks)
                        }
                    }
                    if !doneTasks.isEmpty {
                        DashboardCardView(title: "Completate", subtitle: "Ultime registrazioni") {
                            taskList(doneTasks.prefix(30).map { $0 })
                        }
                    }
                }
            }
            .padding(theme.spacing.screenPadding + 8)
        }
    }

    private var statsRow: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Da fare",
                value: "\(todoTasks.count)",
                subtitle: "In programma",
                icon: "checklist",
                accent: theme.colorInfo
            )
            StatCard(
                title: "In ritardo",
                value: "\(overdueTasks.count)",
                subtitle: overdueTasks.isEmpty ? "Tutto in regola" : "Da gestire",
                icon: "exclamationmark.triangle.fill",
                accent: overdueTasks.isEmpty ? theme.colorTextSecondary : theme.colorWarning
            )
            StatCard(
                title: "Completate",
                value: "\(doneTasks.count)",
                subtitle: "Totali",
                icon: "checkmark.circle.fill",
                accent: theme.colorSuccess
            )
        }
    }

    private func taskList(_ items: [ScheduledTask]) -> some View {
        LazyVStack(spacing: 10) {
            ForEach(items) { task in
                ScheduledTaskRow(
                    task: task,
                    isOverdue: vm.service.isOverdue(task),
                    onToggle: { toggle(task) },
                    onDelete: { taskPendingDelete = task }
                )
            }
        }
    }

    private func toggle(_ task: ScheduledTask) {
        HapticManager.shared.selection()
        do {
            try vm.service.setCompleted(task, completed: !task.isCompleted, user: currentUser, modelContext: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ task: ScheduledTask) {
        do {
            try vm.service.delete(task, modelContext: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Row

private struct ScheduledTaskRow: View {
    let task: ScheduledTask
    let isOverdue: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? theme.colorSuccess : theme.colorTextSecondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                    .strikethrough(task.isCompleted, color: theme.colorTextSecondary)

                if !task.taskDescription.isEmpty {
                    Text(task.taskDescription)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Label(task.frequency.label, systemImage: task.frequency.icon)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                    if let due = task.dueAt {
                        Text("· Scade \(due.formatted(date: .abbreviated, time: .omitted))")
                            .font(theme.typography.caption)
                            .foregroundStyle(isOverdue ? theme.colorWarning : theme.colorTextSecondary)
                    }
                }
            }

            Spacer(minLength: 0)

            if task.isCompleted {
                HACCPBadge(title: "Fatto", style: .conforme, showIcon: false)
            } else if isOverdue {
                HACCPBadge(title: "In ritardo", style: .warning, showIcon: false)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .fill(theme.colorSurface)
        )
        .overlay(alignment: .leading) {
            if isOverdue {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.colorWarning)
                    .frame(width: 4)
                    .padding(.vertical, 8)
            }
        }
        .contextMenu {
            Button(task.isCompleted ? "Segna da fare" : "Segna completata", systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark") {
                onToggle()
            }
            Button("Elimina", systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
    }
}
