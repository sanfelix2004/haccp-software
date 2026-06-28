import SwiftUI
import SwiftData

/// Associazione rapida a un singolo piatto (senza uscire dall'archivio).
struct TraceabilityQuickAssociateSheet: View {
    let record: TraceabilityRecord
    let productions: [Production]
    let categories: [ProductionCategory]
    let onConfirm: (Production) -> Void
    let onCancel: () -> Void

    @Environment(\.theme) private var theme
    @State private var selectedCategoryId: UUID?
    @State private var selectedProduction: Production?

    private var filteredProductions: [Production] {
        guard let selectedCategoryId else { return productions }
        return productions.filter { $0.categoryId == selectedCategoryId }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.productName)
                            .font(theme.typography.headline)
                        if !record.lotCode.isEmpty {
                            Text("Lotto \(record.lotCode)")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary)
                        }
                    }

                    Text("Scegli il piatto a cui collegare questo lotto.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)

                    categoryTabs

                    if filteredProductions.isEmpty {
                        Text("Nessun piatto in questa categoria.")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                    } else {
                        BlastChillingProductionGridView(
                            productions: filteredProductions,
                            selectedProductionId: selectedProduction?.id,
                            showsShelfLife: true,
                            onSelect: { selectedProduction = $0 }
                        )
                    }
                }
                .padding()
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle("Associa piatto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Conferma") {
                        if let production = selectedProduction {
                            onConfirm(production)
                        }
                    }
                    .disabled(selectedProduction == nil)
                }
            }
        }
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryButton(nil, title: "Tutte")
                ForEach(categories) { category in
                    categoryButton(category.id, title: category.name)
                }
            }
        }
    }

    private func categoryButton(_ id: UUID?, title: String) -> some View {
        Button {
            selectedCategoryId = id
        } label: {
            Text(title)
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(selectedCategoryId == id ? theme.colorTextOnPrimary : theme.colorTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedCategoryId == id ? theme.colorPrimary : theme.colorDivider)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
