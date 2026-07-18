//
//  DefrostCompleteSheet.swift
//

import SwiftUI
import SwiftData

struct DefrostCompleteSheet: View {
    let record: DefrostRecord
    let user: LocalUser
    let criticalities: [DefrostCriticality]
    let onCompleted: () -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @State private var draft = DefrostCompleteDraft()
    @State private var errorMessage: String?

    private let service = DefrostService()
    private var requiresCriticalityFields: Bool {
        draft.outcome == .nonConforme
            || service.isTemperatureNonConforme(
                method: record.defrostMethod,
                temperature: draft.parsedFinalTemperature
            )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacing.sectionSpacing) {
                    DefrostRecordCardView(record: record)

                    DashboardCardView(title: "Chiusura processo") {
                        VStack(spacing: 14) {
                            Text("L'ora di fine viene registrata al momento del salvataggio.")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary)

                            if let initial = record.initialTemperature {
                                HStack {
                                    Text("Temperatura iniziale")
                                        .font(theme.typography.caption)
                                        .foregroundStyle(theme.colorTextSecondary)
                                    Spacer()
                                    Text(String(format: "%.1f °C", initial))
                                        .font(theme.typography.subheadline.weight(.semibold))
                                }
                            }

                            TextField("Temperatura finale °C *", text: $draft.finalTemperature)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)

                            Picker("Esito", selection: $draft.outcome) {
                                ForEach(DefrostOutcome.allCases, id: \.self) { o in
                                    Text(o.label).tag(o)
                                }
                            }
                            .pickerStyle(.segmented)

                            TextField("Note", text: $draft.notes, axis: .vertical)
                                .lineLimit(2...4)
                                .textFieldStyle(.roundedBorder)

                            if requiresCriticalityFields {
                                Text("Non conformità: motivo e azione correttiva obbligatori.")
                                    .font(theme.typography.caption)
                                    .foregroundStyle(theme.colorWarning)
                                TextField("Motivo criticità *", text: $draft.criticalityReason, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Azione correttiva *", text: $draft.correctiveAction, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                }
                .padding(theme.spacing.screenPadding + 8)
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle("Completa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { complete() }
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

    private func complete() {
        do {
            try service.completeDefrost(
                record: record,
                draft: draft,
                user: user,
                modelContext: modelContext,
                criticalities: criticalities
            )
            onCompleted()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
