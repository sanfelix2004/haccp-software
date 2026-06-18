import SwiftUI

struct ChecklistAlertsView: View {
    let alerts: [ChecklistAlert]
    let onResolve: (ChecklistAlert, String) -> Void

    @Environment(\.theme) private var theme
    @State private var selectedAlert: ChecklistAlert?
    @State private var correctiveAction = ""
    @State private var showResolveSheet = false
    @State private var validationMessage: String?

    private var activeAlerts: [ChecklistAlert] {
        alerts.filter { $0.isActive }.sorted(by: { $0.createdAt > $1.createdAt })
    }

    private var resolvedAlerts: [ChecklistAlert] {
        alerts.filter { !$0.isActive }.sorted(by: { ($0.resolvedAt ?? .distantPast) > ($1.resolvedAt ?? .distantPast) })
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing.sectionSpacing) {
                ModuleScreenHeader(
                    title: "Criticità checklist",
                    subtitle: "Attività segnate NON OK e azioni correttive",
                    systemImage: "exclamationmark.triangle.fill"
                )

                if activeAlerts.isEmpty && resolvedAlerts.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessuna criticità",
                        message: "Le criticità compariranno quando un'attività viene segnata NON OK durante una checklist.",
                        actionTitle: nil
                    ))
                } else {
                    if !activeAlerts.isEmpty {
                        DashboardCardView(title: "Da risolvere", subtitle: "\(activeAlerts.count) aperte") {
                            LazyVStack(spacing: 10) {
                                ForEach(activeAlerts) { alert in
                                    alertRow(alert, resolved: false)
                                }
                            }
                        }
                    }

                    if !resolvedAlerts.isEmpty {
                        DashboardCardView(title: "Risolte", subtitle: "Storico azioni correttive") {
                            LazyVStack(spacing: 10) {
                                ForEach(resolvedAlerts.prefix(30)) { alert in
                                    alertRow(alert, resolved: true)
                                }
                            }
                        }
                    }
                }
            }
            .padding(theme.spacing.screenPadding)
        }
        .sheet(isPresented: $showResolveSheet) {
            resolveSheet
        }
    }

    @ViewBuilder
    private func alertRow(_ alert: ChecklistAlert, resolved: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: resolved ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(resolved ? theme.colorSuccess : theme.colorError)
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.message)
                        .font(theme.typography.subheadline)
                        .foregroundStyle(theme.colorTextPrimary)
                    Text(alert.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
                Spacer(minLength: 0)
                HACCPBadge(
                    title: resolved ? ChecklistAlertStatus.resolved.label : ChecklistAlertStatus.active.label,
                    style: resolved ? .conforme : .nonConforme,
                    showIcon: false
                )
            }

            if let action = alert.correctiveAction, !action.isEmpty {
                Label(action, systemImage: "wrench.and.screwdriver.fill")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            }

            if let resolvedAt = alert.resolvedAt, let name = alert.resolvedByName {
                Text("Risolta da \(name) · \(resolvedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(theme.typography.caption2)
                    .foregroundStyle(theme.colorTextSecondary)
            }

            if !resolved {
                SecondaryButton(title: "Registra azione correttiva", icon: "checkmark.circle") {
                    selectedAlert = alert
                    correctiveAction = ""
                    validationMessage = nil
                    showResolveSheet = true
                }
            }
        }
        .padding(14)
        .background(resolved ? theme.colorSurface : theme.colorError.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
    }

    private var resolveSheet: some View {
        NavigationStack {
            Form {
                Section {
                    if let selectedAlert {
                        Text(selectedAlert.message)
                            .font(.subheadline)
                    }
                }
                Section("Azione correttiva") {
                    TextField("Descrivi cosa è stato fatto per risolvere", text: $correctiveAction, axis: .vertical)
                        .lineLimit(3...6)
                }
                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(theme.colorError)
                }
            }
            .navigationTitle("Risolvi criticità")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { showResolveSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Conferma") {
                        let text = correctiveAction.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else {
                            validationMessage = "Azione correttiva obbligatoria."
                            return
                        }
                        guard let selectedAlert else { return }
                        onResolve(selectedAlert, text)
                        showResolveSheet = false
                    }
                }
            }
        }
    }
}
