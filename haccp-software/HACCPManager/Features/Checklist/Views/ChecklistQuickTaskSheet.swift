import SwiftUI
import SwiftData

struct ChecklistQuickTaskSheet: View {
    let restaurantId: UUID
    let user: LocalUser
    let service: ChecklistService
    let onSaved: () -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @State private var title = ""
    @State private var description = ""
    @State private var frequency: ChecklistFrequency = .daily
    @State private var scheduledTime = Calendar.current.date(
        bySettingHour: 9,
        minute: 0,
        second: 0,
        of: Date()
    ) ?? Date()
    @State private var errorMessage: String?

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Attività") {
                    TextField("Titolo (es. Controllo estintori)", text: $title)
                    TextField("Descrizione (facoltativa)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Ricorrenza") {
                    Picker("Frequenza", selection: $frequency) {
                        ForEach(ChecklistFrequency.allCases.filter { $0 != .custom }, id: \.self) { freq in
                            Text(freq.label).tag(freq)
                        }
                    }
                    .pickerStyle(.menu)

                    if frequency != .onDemand {
                        DatePicker("Orario previsto", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section {
                    Text("L'attività viene registrata come checklist con tracciamento operatore e storico auditabile.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }
            .navigationTitle("Nuova attività rapida")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva", action: save).disabled(!canSave)
                }
            }
            .alert("Errore", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .haccpControlTint()
    }

    private func save() {
        let calendar = Calendar.current
        do {
            _ = try service.createQuickTaskTemplate(
                restaurantId: restaurantId,
                title: title,
                description: description,
                frequency: frequency,
                scheduledHour: frequency == .onDemand ? nil : calendar.component(.hour, from: scheduledTime),
                scheduledMinute: frequency == .onDemand ? nil : calendar.component(.minute, from: scheduledTime),
                createdBy: user,
                modelContext: modelContext
            )
            HapticManager.shared.notification(.success)
            onSaved()
        } catch {
            errorMessage = "Salvataggio non riuscito."
        }
    }
}
