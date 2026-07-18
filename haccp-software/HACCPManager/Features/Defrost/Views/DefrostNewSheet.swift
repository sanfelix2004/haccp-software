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
    let onContinue: (KitchenProcessSubject) -> Void
    let onCancel: () -> Void

    @Environment(\.theme) private var theme

    @State private var subject = KitchenProcessSubject(
        source: .traceability,
        traceabilityItemId: nil,
        productTemplateId: nil,
        productionId: nil,
        productName: "",
        lotNumber: nil,
        categoryName: nil
    )

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
                    Button("Continua") { onContinue(subject) }
                        .disabled(!subject.isValid)
                }
            }
        }
    }
}
