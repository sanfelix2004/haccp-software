import SwiftUI
import SwiftData

/// Chiusura operativa da Controllo scadenze (ingresso e produzioni interne).
enum ExpiryLotClosureKind: String, CaseIterable, Identifiable {
    case finished
    case discarded
    case expired

    var id: String { rawValue }

    var label: String {
        switch self {
        case .finished: return "Terminato"
        case .discarded: return "Scartato"
        case .expired: return "Scaduto"
        }
    }

    var subtitle: String {
        switch self {
        case .finished: return "Consumato, venduto o finito in cucina"
        case .discarded: return "Eliminato / non utilizzabile — serve una motivazione"
        case .expired: return "Eliminato perché scaduto (nessuna motivazione richiesta)"
        }
    }

    var requiresNote: Bool {
        switch self {
        case .finished, .expired: return false
        case .discarded: return true
        }
    }

    /// «Scaduto» selezionabile solo se non c’è data, oppure se la data è già passata.
    func isSelectable(for record: TraceabilityRecord, now: Date = Date()) -> Bool {
        switch self {
        case .finished, .discarded:
            return true
        case .expired:
            guard let expiry = record.expiryDate else { return true }
            return record.productStatus == .expired
                || ProductExpiryEvaluator.isExpiredByDate(expiry, now: now)
        }
    }

    var logDetail: String { label }
}

struct ExpiryLotClosureSheet: View {
    let record: TraceabilityRecord
    let user: LocalUser
    /// Contesto UI: ingresso vs produzione (copy).
    var isProduction: Bool = false
    let onSaved: () -> Void
    let onCancel: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var kind: ExpiryLotClosureKind = .finished
    @State private var note = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    private let archiveService = ExpiryArchiveService()

    private var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canConfirm: Bool {
        if kind.requiresNote { return !trimmedNote.isEmpty }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(isProduction
                       ? "Chiudi questo piatto di produzione: terminato, scartato o eliminato perché scaduto."
                       : "Chiudi questo alimento in ingresso: terminato, scartato o eliminato perché scaduto.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }

                Section(isProduction ? "Produzione" : "Alimento") {
                    if let photo = record.photoData, !photo.isEmpty,
                       let thumb = HACCPZoomablePhotoThumbnail(
                        data: photo,
                        size: 96,
                        zoomTitle: record.productName
                       ) {
                        thumb
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    LabeledContent("Nome", value: record.productName)
                    LabeledContent(
                        isProduction ? "Lotto produzione" : "Lotto",
                        value: record.lotCode.isEmpty ? "—" : record.lotCode
                    )
                    if let expiry = record.expiryDate {
                        LabeledContent(
                            "Scadenza",
                            value: expiry.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                }

                Section("Esito") {
                    ForEach(ExpiryLotClosureKind.allCases) { option in
                        let selectable = option.isSelectable(for: record)
                        Button {
                            guard selectable else { return }
                            kind = option
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: kind == option ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(
                                        selectable
                                            ? (kind == option ? theme.colorPrimary : theme.colorTextSecondary)
                                            : theme.colorTextSecondary.opacity(0.35)
                                    )
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(option.label)
                                        .font(theme.typography.subheadline.weight(.semibold))
                                        .foregroundStyle(
                                            selectable ? theme.colorTextPrimary : theme.colorTextSecondary.opacity(0.45)
                                        )
                                    Text(option.subtitle)
                                        .font(theme.typography.caption)
                                        .foregroundStyle(theme.colorTextSecondary.opacity(selectable ? 1 : 0.55))
                                    if !selectable, option == .expired, record.expiryDate != nil {
                                        Text("Disponibile solo dopo la data di scadenza registrata.")
                                            .font(theme.typography.caption2)
                                            .foregroundStyle(theme.colorWarning)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!selectable)
                        .accessibilityHint(
                            selectable
                                ? ""
                                : "Scaduto non disponibile: la data registrata non è ancora passata."
                        )
                    }
                }

                Section {
                    TextField(
                        kind.requiresNote ? "Motivazione obbligatoria…" : "Nota opzionale…",
                        text: $note,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                } header: {
                    Text(kind.requiresNote ? "Motivazione (obbligatoria)" : "Nota (opzionale)")
                } footer: {
                    Text("Esce dalle scadenze attive. La traccia resta in Documenti e nello storico operativo.")
                        .font(theme.typography.caption2)
                }
            }
            .navigationTitle(isProduction ? "Chiudi produzione" : "Chiudi alimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        onCancel()
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Conferma") { confirm() }
                        .disabled(!canConfirm || isSubmitting)
                        .fontWeight(.semibold)
                }
            }
            .alert("Chiusura", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled(isSubmitting)
    }

    private func confirm() {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            guard kind.isSelectable(for: record) else {
                errorMessage = "«Scaduto» è disponibile solo senza data registrata, oppure dopo la scadenza."
                return
            }
            try archiveService.archive(
                record: record,
                kind: kind,
                note: trimmedNote.nilIfEmpty,
                user: user,
                modelContext: modelContext
            )
            HapticManager.shared.notification(.success)
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
