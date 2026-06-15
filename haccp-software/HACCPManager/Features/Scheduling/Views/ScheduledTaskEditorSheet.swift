import SwiftUI
import SwiftData

struct ScheduledTaskEditorSheet: View {
    let restaurantId: UUID
    let user: LocalUser
    let onSaved: () -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @State private var title = ""
    @State private var description = ""
    @State private var frequency: SchedulingFrequency = .daily
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var errorMessage: String?

    private let service = SchedulingService()

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Attività") {
                    TextField("Titolo (es. Controllo temperature frigo)", text: $title)
                    TextField("Descrizione (facoltativa)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Frequenza") {
                    Picker("Ricorrenza", selection: $frequency) {
                        ForEach(SchedulingFrequency.allCases) { freq in
                            Label(freq.label, systemImage: freq.icon).tag(freq)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Scadenza") {
                    Toggle("Imposta una scadenza", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Scade il", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("Nuova attività")
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
        do {
            try service.createTask(
                restaurantId: restaurantId,
                title: title,
                description: description,
                frequency: frequency,
                dueAt: hasDueDate ? dueDate : nil,
                user: user,
                modelContext: modelContext
            )
            HapticManager.shared.notification(.success)
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
