import SwiftUI
import SwiftData

/// Modifica dati di un alimento in ingresso o di una produzione già registrata.
struct TraceabilityRecordEditSheet: View {
    let record: TraceabilityRecord
    let batch: ProduzioneBatch?
    let user: LocalUser
    let onSaved: () -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @State private var productName: String
    @State private var lotCode: String
    @State private var supplier: String
    @State private var receivedAt: Date
    @State private var hasExpiry: Bool
    @State private var expiryDate: Date
    @State private var notes: String
    @State private var batchNotes: String
    @State private var errorMessage: String?
    @State private var isSaving = false

    private let service = TraceabilityService()

    private var isProductionOutput: Bool {
        record.produzioneBatchId != nil || batch != nil
    }

    init(
        record: TraceabilityRecord,
        batch: ProduzioneBatch? = nil,
        user: LocalUser,
        onSaved: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.record = record
        self.batch = batch
        self.user = user
        self.onSaved = onSaved
        self.onCancel = onCancel
        _productName = State(initialValue: record.productName)
        _lotCode = State(initialValue: record.lotCode)
        _supplier = State(initialValue: record.supplier)
        _receivedAt = State(initialValue: batch?.producedAt ?? record.receivedAt)
        _hasExpiry = State(initialValue: record.expiryDate != nil || batch?.internalExpiryAt != nil)
        _expiryDate = State(initialValue: record.expiryDate ?? batch?.internalExpiryAt ?? Date())
        _notes = State(initialValue: record.notes ?? "")
        _batchNotes = State(initialValue: batch?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(isProductionOutput ? "Nome produzione" : "Alimento", text: $productName)
                    TextField(isProductionOutput ? "Lotto produzione" : "Lotto fornitore", text: $lotCode)
                        .textInputAutocapitalization(.characters)
                    if !isProductionOutput {
                        TextField("Fornitore", text: $supplier)
                    }
                } header: {
                    Text(isProductionOutput ? "Produzione" : "Alimento in ingresso")
                } footer: {
                    Text("Usa questa correzione se hai sbagliato a digitare i dati. Per scadenze/scarto/usato usa Controllo scadenze.")
                }

                Section("Date") {
                    DatePicker(
                        isProductionOutput ? "Data produzione" : "Data ingresso",
                        selection: $receivedAt,
                        displayedComponents: [.date]
                    )
                    Toggle("Ha scadenza", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Scadenza", selection: $expiryDate, displayedComponents: [.date])
                    }
                }

                Section("Note") {
                    TextField("Note", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                    if isProductionOutput {
                        TextField("Note batch", text: $batchNotes, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }
            }
            .navigationTitle("Modifica dati")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { save() }
                        .disabled(isSaving || productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Modifica", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        isSaving = true
        defer { isSaving = false }
        do {
            try service.updateRecord(
                record: record,
                productName: productName,
                lotCode: lotCode,
                supplier: isProductionOutput ? record.supplier : supplier,
                receivedAt: receivedAt,
                expiryDate: hasExpiry ? expiryDate : nil,
                notes: notes,
                user: user,
                modelContext: modelContext,
                batchProducedAt: isProductionOutput ? receivedAt : nil,
                batchNotes: isProductionOutput ? batchNotes : nil
            )
            HapticManager.shared.notification(.success)
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
