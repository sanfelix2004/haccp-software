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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Registra la chiusura del lotto scaduto per tracciabilità HACCP. Il prodotto non sarà più utilizzabile in cucina.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }

                Section("Prodotto") {
                    LabeledContent("Nome", value: record.productName)
                    LabeledContent("Lotto", value: record.lotCode.isEmpty ? "—" : record.lotCode)
                    if let expiry = record.expiryDate {
                        LabeledContent(
                            "Scadenza",
                            value: expiry.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                }

                Section("Tipo intervento") {
                    Picker("Esito", selection: $kind) {
                        ForEach(TraceabilityWithdrawalKind.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(kind.subtitle)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }

                Section("Note (opzionale)") {
                    TextField("Es. contenitore, ubicazione, motivo aggiuntivo…", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Usato / scarto")
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
                        .disabled(isSubmitting || !record.canBeWithdrawn)
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
