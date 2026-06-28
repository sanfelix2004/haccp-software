import SwiftUI
import SwiftData

struct TraceabilityNonComplianceSheet: View {
    let record: TraceabilityRecord
    let user: LocalUser
    let onSaved: () -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var note = ""
    @State private var correctiveAction = ""
    @State private var errorMessage: String?

    private let service = TraceabilityService()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Motivo e azione correttiva sono obbligatori.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Motivo") {
                    TextField("Es. confezione danneggiata…", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("Azione correttiva") {
                    TextField("Cosa fate per gestire la criticità", text: $correctiveAction, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Non conformità")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Conferma", action: confirm)
                }
            }
            .alert("Errore", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func confirm() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAction = correctiveAction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty, !trimmedAction.isEmpty else {
            errorMessage = "Compila motivo e azione correttiva."
            return
        }
        do {
            try service.markNonCompliant(
                record: record,
                note: trimmedNote,
                correctiveAction: trimmedAction,
                user: user,
                modelContext: modelContext
            )
            HapticManager.shared.notification(.success)
            onSaved()
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }
}
