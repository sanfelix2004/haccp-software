import SwiftUI

/// Sheet MASTER: motivo obbligatorio prima di nascondere una voce dallo storico.
struct HistoryRemovalReasonSheet: View {
    let title: String
    let subtitle: String
    let onConfirm: (HistoryRemovalReason, String?) -> Void
    let onCancel: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var reason: HistoryRemovalReason = .finished
    @State private var note = ""

    private var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canConfirm: Bool {
        if reason.requiresNote {
            return !trimmedNote.isEmpty
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(subtitle)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }

                Section("Motivo") {
                    ForEach(HistoryRemovalReason.allCases) { option in
                        Button {
                            reason = option
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: reason == option ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(reason == option ? theme.colorPrimary : theme.colorTextSecondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(option.label)
                                        .font(theme.typography.subheadline.weight(.semibold))
                                        .foregroundStyle(theme.colorTextPrimary)
                                    Text(option.subtitle)
                                        .font(theme.typography.caption)
                                        .foregroundStyle(theme.colorTextSecondary)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    TextField(
                        reason.requiresNote ? "Motivo obbligatorio…" : "Nota opzionale…",
                        text: $note,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                } header: {
                    Text(reason.requiresNote ? "Nota (obbligatoria)" : "Nota (opzionale)")
                } footer: {
                    Text("La voce sparisce dallo storico operativo. In Documenti restano lotto, ingredienti e questo motivo.")
                        .font(theme.typography.caption2)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Nascondi") {
                        let noteValue = trimmedNote.isEmpty ? nil : trimmedNote
                        onConfirm(reason, noteValue)
                        dismiss()
                    }
                    .disabled(!canConfirm)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
