import SwiftUI
import SwiftData

/// Scatta etichetta → lotto modificabile → alimento in ingresso.
struct ProduzioneBatchLiveCaptureView: View {
    @Bindable var batch: ProduzioneBatch
    let user: LocalUser
    var onUpdated: () -> Void = {}
    var onCompleted: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @Query private var allImages: [ProductImage]
    @Query private var productTemplates: [ProductTemplate]

    @State private var ingredients: [IngredienteTracciato] = []
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @StateObject private var camera = FinalizeReceiptCameraViewModel()

    private let batchService = ProduzioneBatchService()
    private let ingredientService = IngredienteTracciatoService()

    private var scopedTemplates: [ProductTemplate] {
        productTemplates
            .filter { $0.restaurantId == batch.restaurantId }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var incomingFoodOptions: [RecipeIngredientOption] {
        ingredientService.incomingFoodOptions(from: scopedTemplates)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                FullScreenLotCameraView(
                    camera: camera,
                    isProcessing: isProcessing,
                    onCapture: { camera.capturePhoto() }
                )
                .frame(height: max(geometry.size.height * 0.5, 320))

                tracesPanel
            }
        }
        .onAppear {
            ProductTemplateSeeder.ensureTemplates(restaurantId: batch.restaurantId, modelContext: modelContext)
            try? batchService.ensureInternalLotCode(batch: batch, modelContext: modelContext)
            reloadIngredients()
            camera.start()
        }
        .onDisappear { camera.stop() }
        .onReceive(camera.$capturedPhotoData) { data in
            guard let data, !data.isEmpty, !isProcessing, batch.status == .inCorso else { return }
            Task { await processPhoto(data) }
        }
        .alert("Produzione", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var tracesPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ProductionInternalLotBadge(batchCode: batch.batchCode)
                    .padding(.horizontal)
                    .padding(.top, 12)

                Text(batch.productionNameSnapshot)
                    .font(theme.typography.subheadline.weight(.semibold))
                    .foregroundStyle(theme.colorTextPrimary)
                    .padding(.horizontal)

                if ingredients.isEmpty {
                    Text("Scatta l'etichetta fornitore (foto obbligatoria). Il lotto di produzione sopra è già generato e andrà sull'etichetta del piatto.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                        .padding(.horizontal)
                } else {
                    ForEach(ingredients, id: \.id) { item in
                        IngredienteTracciatoGridRow(
                            ingredient: item,
                            imageData: item.photoId.flatMap { imageData(for: $0) },
                            incomingFoodOptions: incomingFoodOptions,
                            onAssignIngredient: { assignIngredient($0, to: item) },
                            onConfirmLot: { confirmLot($0, for: item) }
                        )
                        .padding(.horizontal)
                    }
                }

                if batch.status == .inCorso {
                    Button("Completa produzione") { completeBatch() }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .disabled(ingredients.isEmpty || isProcessing)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
            }
            .padding(.bottom, 24)
        }
        .background(theme.colorBackground)
    }

    private func imageData(for photoId: UUID) -> Data? {
        allImages.first { $0.id == photoId }?.imageData
    }

    private func reloadIngredients() {
        ingredients = ingredientService.ingredients(batchId: batch.id, modelContext: modelContext)
    }

    private func assignIngredient(_ option: RecipeIngredientOption, to item: IngredienteTracciato) {
        do {
            try ingredientService.assignIngredientManually(ingredient: item, option: option, modelContext: modelContext)
            reloadIngredients()
            onUpdated()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirmLot(_ lot: String, for item: IngredienteTracciato) {
        do {
            try ingredientService.confirmLot(ingredient: item, editedLot: lot, modelContext: modelContext)
            reloadIngredients()
            onUpdated()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func processPhoto(_ data: Data) async {
        isProcessing = true
        defer {
            isProcessing = false
            camera.resetCaptureBuffer()
        }
        do {
            _ = try await ingredientService.appendFromPhoto(
                batch: batch,
                photoData: data,
                ingredientNameHint: nil,
                user: user,
                modelContext: modelContext
            )
            reloadIngredients()
            onUpdated()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func completeBatch() {
        do {
            try batchService.completeBatch(
                batch: batch,
                internalExpiryAt: nil,
                ingredientCount: ingredients.count,
                user: user,
                modelContext: modelContext
            )
            onUpdated()
            onCompleted()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
