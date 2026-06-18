//
//  DefrostNewSheet.swift
//

import SwiftUI
import SwiftData

struct DefrostNewSheet: View {
    let restaurantId: UUID
    let user: LocalUser
    let traceabilityRecords: [TraceabilityRecord]
    let incomingFoodTemplates: [ProductTemplate]
    let onSaved: () -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @Bindable private var settingsStorage = SettingsStorageService.shared

    @State private var subject = KitchenProcessSubject(
        source: .traceability,
        traceabilityItemId: nil,
        productTemplateId: nil,
        productionId: nil,
        productName: "",
        lotNumber: nil,
        categoryName: nil
    )
    @State private var method: DefrostMethod = .frigorifero
    @State private var notes = ""
    @State private var errorMessage: String?

    private let service = DefrostService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacing.sectionSpacing) {
                    DashboardCardView(
                        title: "Cosa decongeli?",
                        subtitle: "Lotto tracciato, alimento in ingresso o inserimento rapido"
                    ) {
                        KitchenProcessSubjectPicker(
                            subject: $subject,
                            allowedSources: [.traceability, .incomingFood, .manual],
                            traceabilityRecords: traceabilityRecords,
                            incomingFoodTemplates: incomingFoodTemplates,
                            productions: [],
                            productionCategories: []
                        )
                    }

                    DashboardCardView(title: "Decongelamento") {
                        VStack(spacing: 14) {
                            Picker("Metodo", selection: $method) {
                                ForEach(DefrostMethod.allCases) { m in
                                    Text(m.label).tag(m)
                                }
                            }
                            .pickerStyle(.menu)

                            Text("Il timer parte quando premi Avvia, non prima.")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary)

                            Text("Fine prevista: \(method.expectedEndAt(from: Date(), settings: settingsStorage.haccp).formatted(date: .abbreviated, time: .shortened)) · max \(method.recommendedDurationHours(settings: settingsStorage.haccp)) h")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary)

                            TextField("Note (opzionale)", text: $notes, axis: .vertical)
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
                        .disabled(!subject.isValid)
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

    private func save() {
        var draft = DefrostNewDraft.from(subject: subject)
        draft.method = method
        draft.notes = notes
        do {
            _ = try service.startDefrost(
                draft: draft,
                restaurantId: restaurantId,
                user: user,
                settings: settingsStorage.haccp,
                modelContext: modelContext
            )
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
