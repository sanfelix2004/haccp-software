import SwiftUI
import SwiftData

/// Avvio batch produzione dal catalogo + elenco batch recenti.
struct ProduzioneBatchHubView: View {
    let restaurantId: UUID
    let user: LocalUser
    var onBatchChanged: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @Query private var productions: [Production]
    @Query private var categories: [ProductionCategory]

    @State private var batches: [ProduzioneBatch] = []
    @State private var selectedProduction: Production?
    @State private var activeBatch: ProduzioneBatch?
    @State private var errorMessage: String?

    private let batchService = ProduzioneBatchService()
    private let libraryService = ProductionLibraryService()

    private var scopedProductions: [Production] {
        productions.filter { $0.restaurantId == restaurantId }.sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Produzioni HACCP")
                .font(theme.typography.headline)
                .foregroundStyle(theme.colorTextPrimary)

            Text("Apri un batch (es. Crema Pasticcera) e traccia gli ingredienti scattando foto ai lotti.")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)

            if scopedProductions.isEmpty {
                Text("Nessuna produzione in catalogo.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(scopedProductions.prefix(24)) { production in
                            Button {
                                startBatch(for: production)
                            } label: {
                                Text(production.name)
                                    .font(theme.typography.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(theme.colorPrimary.opacity(0.12))
                                    .foregroundStyle(theme.colorPrimary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !batches.isEmpty {
                Text("Batch recenti")
                    .font(theme.typography.subheadline.weight(.semibold))
                ForEach(batches.prefix(8)) { batch in
                    Button {
                        activeBatch = batch
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(batch.productionNameSnapshot) · \(batch.batchCode)")
                                    .font(theme.typography.subheadline)
                                Text(batch.status.label)
                                    .font(theme.typography.caption2)
                                    .foregroundStyle(theme.colorTextSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(theme.colorTextSecondary)
                        }
                        .padding(10)
                        .background(theme.colorSurfaceElevated.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear(perform: bootstrap)
        .sheet(isPresented: Binding(
            get: { activeBatch != nil },
            set: { if !$0 { activeBatch = nil } }
        )) {
            if let batch = activeBatch {
                ProduzioneBatchDetailView(batch: batch, user: user) {
                    reloadBatches()
                    onBatchChanged()
                }
            }
        }
        .alert("Produzione", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func bootstrap() {
        libraryService.ensureDefaults(
            restaurantId: restaurantId,
            modelContext: modelContext
        )
        reloadBatches()
    }

    private func reloadBatches() {
        batches = batchService.batches(restaurantId: restaurantId, modelContext: modelContext)
    }

    private func startBatch(for production: Production) {
        do {
            let batch = try batchService.startBatch(production: production, user: user, modelContext: modelContext)
            reloadBatches()
            activeBatch = batch
            onBatchChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
