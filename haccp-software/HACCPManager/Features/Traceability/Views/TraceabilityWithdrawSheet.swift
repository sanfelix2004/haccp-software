//
//  TraceabilityWithdrawSheet.swift
//

import SwiftUI
import SwiftData

struct TraceabilityWithdrawSheet: View {
    let record: TraceabilityRecord
    let user: LocalUser
    let onSaved: () -> Void
    let onCancel: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var kind: TraceabilityWithdrawalKind = .ritirato
    @State private var note = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    private let service = TraceabilityService()

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
                    Text(record.isProductionBatchOutput
                       ? "Terminato resta solo in Storia. Scartato richiede motivazione e va anche in Documenti."
                       : "Terminato resta solo in Storia. Scartato richiede motivazione e va anche in Documenti.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }

                Section(record.isProductionBatchOutput ? "Produzione" : "Prodotto") {
                    if !record.isProductionBatchOutput,
                       let photo = record.photoData, !photo.isEmpty,
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
                        record.isProductionBatchOutput ? "Lotto produzione" : "Lotto",
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
                    ForEach(TraceabilityWithdrawalKind.allCases) { option in
                        Button {
                            kind = option
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: kind == option ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(kind == option ? theme.colorPrimary : theme.colorTextSecondary)
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
                    if kind.requiresNote {
                        TextField(
                            "Motivazione obbligatoria…",
                            text: $note,
                            axis: .vertical
                        )
                        .lineLimit(2...4)
                    }
                    Text(withdrawFooter(for: kind))
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                } header: {
                    if kind.requiresNote {
                        Text("Motivazione (obbligatoria)")
                    }
                }
            }
            .navigationTitle("Chiudi lotto scaduto")
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
                    Button("Conferma", action: confirm)
                        .disabled(isSubmitting || !record.canBeWithdrawn || !canConfirm)
                }
            }
            .alert("Usato / scarto", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                if !record.canBeWithdrawn {
                    errorMessage = "Questo lotto non è più eleggibile per ritiro/scarto."
                }
            }
        }
        .interactiveDismissDisabled(isSubmitting)
    }

    private func withdrawFooter(for kind: TraceabilityWithdrawalKind) -> String {
        switch kind {
        case .ritirato:
            return "Terminato: salvato solo in Storia."
        case .scartato:
            return "Scartato: motivazione obbligatoria. Salvato in Storia e Documenti."
        case .scaduto:
            return "Scaduto: salvato in Storia e Documenti."
        }
    }

    private func confirm() {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try service.markWithdrawn(
                record: record,
                kind: kind,
                note: note,
                user: user,
                modelContext: modelContext
            )
            HapticManager.shared.notification(.success)
            onSaved()
            dismiss()
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }
}
