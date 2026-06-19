import SwiftUI
import SwiftData

struct BlastChillingNewSheet: View {
    let productions: [Production]
    let categories: [ProductionCategory]
    let onContinue: (KitchenProcessSubject) -> Void
    let onCancel: () -> Void

    @Environment(\.theme) private var theme

    @State private var subject = KitchenProcessSubject(
        source: .production,
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
                        title: "Cosa abbatti?",
                        subtitle: "Scegli un piatto dal catalogo piatti"
                    ) {
                        KitchenProcessSubjectPicker(
                            subject: $subject,
                            allowedSources: [.production],
                            traceabilityRecords: [],
                            incomingFoodTemplates: [],
                            productions: productions,
                            productionCategories: categories
                        )
                    }

                    DashboardCardView(title: "Catalogo piatti", subtitle: "Gestione separata") {
                        Text("Per aggiungere o modificare i piatti del menu vai in Catalogo piatti nella sezione Alimenti del menu laterale.")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(theme.spacing.screenPadding + 8)
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle("Nuovo abbattimento")
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
