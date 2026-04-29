import SwiftUI

struct ChecklistAlertsView: View {
    let alerts: [ChecklistAlert]
    let onResolve: (ChecklistAlert, String) -> Void

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
        Group {
            if activeAlerts.isEmpty && resolvedAlerts.isEmpty {
                ChecklistEmptyStateView(
                    title: "Nessuna criticita checklist",
                    message: "Le criticita compariranno qui quando un'attivita viene segnata NON OK.",
                    actionTitle: nil
                )
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        if !activeAlerts.isEmpty {
                            sectionTitle("Criticita attive")
                            ForEach(activeAlerts) { alert in
                                HStack(alignment: .top) {
                                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(alert.message).foregroundColor(.white)
                                        Text(alert.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text("Stato: \(ChecklistAlertStatus.active.label)")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                    }
                                    Spacer()
                                    Button("Risolvi") {
                                        selectedAlert = alert
                                        correctiveAction = ""
                                        validationMessage = nil
                                        showResolveSheet = true
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding(12)
                                .background(Color.red.opacity(0.12))
                                .cornerRadius(12)
                            }
                        }

                        if !resolvedAlerts.isEmpty {
                            sectionTitle("Storico criticita risolte")
                            ForEach(resolvedAlerts.prefix(30)) { alert in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(alert.message).foregroundColor(.white)
                                    Text("Stato: \(ChecklistAlertStatus.resolved.label)")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    if let correctiveAction = alert.correctiveAction {
                                        Text("Azione correttiva: \(correctiveAction)")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.85))
                                    }
                                    if let resolvedAt = alert.resolvedAt, let resolvedByName = alert.resolvedByName {
                                        Text("Risolta da \(resolvedByName) · \(resolvedAt.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showResolveSheet) {
            NavigationStack {
                Form {
                    Section("Azione correttiva") {
                        TextField("Descrivi l'azione correttiva", text: $correctiveAction, axis: .vertical)
                            .lineLimit(3...6)
                    }
                    if let validationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .navigationTitle("Risolvi criticita")
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

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
