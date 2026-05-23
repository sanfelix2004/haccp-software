//
//  DefrostNewSheet.swift
//

import SwiftUI
import SwiftData

struct DefrostNewSheet: View {
    let restaurantId: UUID
    let user: LocalUser
    let traceabilityRecords: [TraceabilityRecord]
    let onSaved: () -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @State private var draft = DefrostNewDraft()
    @State private var useTraceability = false
    @State private var selectedTraceId: UUID?
    @State private var errorMessage: String?

    private let service = DefrostService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacing.sectionSpacing) {
                    DashboardCardView(title: "Prodotto", subtitle: "Da tracciabilità o manuale") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Collega a tracciabilità", isOn: $useTraceability)
                                .font(theme.typography.subheadline)

                            if useTraceability {
                                Picker("Prodotto tracciato", selection: $selectedTraceId) {
                                    Text("Seleziona…").tag(UUID?.none)
                                    ForEach(traceabilityRecords) { item in
                                        Text("\(item.productName) · \(item.lotCode)")
                                            .tag(Optional(item.id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: selectedTraceId) { _, newId in
                                    applyTraceability(newId)
                                }
                            } else {
                                TextField("Nome prodotto *", text: $draft.productName)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Lotto", text: $draft.lotNumber)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }

                    DashboardCardView(title: "Decongelamento") {
                        VStack(spacing: 14) {
                            Picker("Metodo", selection: $draft.method) {
                                ForEach(DefrostMethod.allCases) { m in
                                    Text(m.label).tag(m)
                                }
                            }
                            .pickerStyle(.menu)

                            DatePicker("Ora inizio", selection: $draft.startAt)

                            Text("Terminerai il decongelamento manualmente quando il prodotto è pronto.")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary)

                            TextField("Note (opzionale)", text: $draft.notes, axis: .vertical)
                                .lineLimit(2...4)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .padding(theme.spacing.screenPadding + 8)
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle("Nuovo decongelamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Avvia") { save() }
                        .disabled(!draft.isValid)
                }
            }
            .alert("Decongelamento", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func applyTraceability(_ id: UUID?) {
        guard let id, let trace = traceabilityRecords.first(where: { $0.id == id }) else { return }
        draft = service.draft(from: trace)
        draft.method = .frigorifero
    }

    private func save() {
        if draft.startAt > Date() {
            draft.startAt = Date()
        }
        do {
            _ = try service.startDefrost(
                draft: draft,
                restaurantId: restaurantId,
                user: user,
                modelContext: modelContext
            )
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
