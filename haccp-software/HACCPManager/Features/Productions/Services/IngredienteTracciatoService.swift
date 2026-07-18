import Foundation
import SwiftData

/// Persistenza tracce lotto: Produzione (batch) ← Foto ← Groq AI ← Lotto.
struct IngredienteTracciatoService {
    private let capturePipeline = ProductionLotCapturePipeline()
    private let recipeService = ProductionIncomingIngredientService()

    func ingredients(
        batchId: UUID,
        modelContext: ModelContext
    ) -> [IngredienteTracciato] {
        let descriptor = FetchDescriptor<IngredienteTracciato>(
            sortBy: [SortDescriptor(\IngredienteTracciato.sequenceIndex)]
        )
        return ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.produzioneBatchId == batchId }
    }

    func lotBindings(
        for batch: ProduzioneBatch,
        modelContext: ModelContext
    ) -> [ProductionLotBinding] {
        ingredients(batchId: batch.id, modelContext: modelContext)
            .compactMap { $0.lotBinding(productionId: batch.productionId) }
    }

    func recipeIngredients(for batch: ProduzioneBatch, modelContext: ModelContext) -> [String] {
        recipeService.resolvedIngredientNames(
            productionId: batch.productionId,
            productionName: batch.productionNameSnapshot,
            modelContext: modelContext
        )
    }

    /// Tutti gli alimenti in ingresso disponibili per assegnazione manuale.
    func incomingFoodOptions(from templates: [ProductTemplate]) -> [RecipeIngredientOption] {
        templates.map { RecipeIngredientOption(name: $0.name, productTemplateId: $0.id) }
    }

    func pendingRecipeOptions(
        batch: ProduzioneBatch,
        modelContext: ModelContext
    ) -> [RecipeIngredientOption] {
        let tracked = ingredients(batchId: batch.id, modelContext: modelContext)
        let links = recipeService.pendingRecipeLinks(
            productionId: batch.productionId,
            tracked: tracked,
            modelContext: modelContext
        )
        if !links.isEmpty {
            return links.map(RecipeIngredientOption.init(link:))
        }
        let recipe = recipeIngredients(for: batch, modelContext: modelContext)
        return ProductionRecipeCatalog.pendingIngredients(recipe: recipe, tracked: tracked)
            .map { RecipeIngredientOption(name: $0) }
    }

    func pendingOptions(
        for item: IngredienteTracciato,
        batch: ProduzioneBatch,
        allTracked: [IngredienteTracciato],
        fallbackTemplates: [ProductTemplate],
        modelContext: ModelContext
    ) -> [RecipeIngredientOption] {
        let others = allTracked.filter { $0.id != item.id }
        let links = recipeService.pendingRecipeLinks(
            productionId: batch.productionId,
            tracked: others,
            modelContext: modelContext
        )
        if !links.isEmpty {
            return links.map(RecipeIngredientOption.init(link:))
        }

        let recipe = recipeIngredients(for: batch, modelContext: modelContext)
        let pendingNames = ProductionRecipeCatalog.pendingIngredients(recipe: recipe, tracked: others)
        if !pendingNames.isEmpty {
            return pendingNames.map { RecipeIngredientOption(name: $0) }
        }

        let assignedTemplateIds = Set(others.compactMap(\.productTemplateId))
        let assignedNames = Set(
            others.compactMap(\.ingredientNameAssigned).map {
                ProductionRecipeCatalog.normalizeIngredientName($0)
            }
        )
        return fallbackTemplates
            .filter { template in
                !assignedTemplateIds.contains(template.id)
                    && !assignedNames.contains(ProductionRecipeCatalog.normalizeIngredientName(template.name))
            }
            .map { RecipeIngredientOption(name: $0.name, productTemplateId: $0.id) }
    }

    /// Scatta foto etichetta → salva su disco/DB (lotto ancora nullable) → OCR → legame Produzione+Foto+Lotto.
    @discardableResult
    func appendFromPhoto(
        batch: ProduzioneBatch,
        photoData: Data,
        ingredientNameHint: String?,
        user: LocalUser,
        modelContext: ModelContext
    ) async throws -> IngredienteTracciato {
        guard batch.status == .inCorso else {
            throw NSError(domain: "IngredienteTracciatoService", code: 1, userInfo: [NSLocalizedDescriptionKey: "La produzione non è più modificabile."])
        }
        guard !photoData.isEmpty else { throw LabelLotError.invalidImage }

        let existing = ingredients(batchId: batch.id, modelContext: modelContext)
        let sequenceIndex = (existing.map(\.sequenceIndex).max() ?? -1) + 1
        let photoId = UUID()
        let stored = try LottoFotoImageStorage.save(
            photoData: photoData,
            restaurantId: batch.restaurantId,
            lottoFotoId: photoId
        )
        let inline = StoredImageCompression.preparedForStorage(photoData) ?? photoData

        // Foto senza lotto confermato: receivedItemId NULL, collegata al batch.
        modelContext.insert(
            ProductImage(
                id: photoId,
                receivedItemId: nil,
                produzioneBatchId: batch.id,
                imageData: inline,
                localPath: stored.originalPath,
                type: .lotLabelOCR,
                createdByUserId: user.id,
                createdByNameSnapshot: user.name
            )
        )

        var trace = IngredienteTracciato(
            produzioneBatchId: batch.id,
            restaurantId: batch.restaurantId,
            sequenceIndex: sequenceIndex,
            photoId: photoId,
            ingredientNameHint: ingredientNameHint?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            stato: .ocrInAttesa
        )
        modelContext.insert(trace)

        do {
            let outcome = try await capturePipeline.process(
                photoData: photoData,
                expectedIngredientNames: []
            )
            applyCaptureOutcome(outcome, to: trace)
        } catch {
            trace.stato = .richiedeLotto
        }

        try modelContext.save()
        KitchenProcessNotifications.postRecordsDidChange()
        return trace
    }

    /// Collega una foto temporanea del batch al lotto/voce di tracciabilità definitiva.
    func attachPhotoToTraceabilityRecord(
        photoId: UUID?,
        record: TraceabilityRecord,
        modelContext: ModelContext
    ) {
        guard let photoId else { return }
        let images = (try? modelContext.fetch(FetchDescriptor<ProductImage>())) ?? []
        guard let image = images.first(where: { $0.id == photoId }) else { return }
        image.receivedItemId = record.id
        if record.photoData == nil || record.photoData?.isEmpty == true {
            record.photoData = image.imageData
        }
    }

    /// Foto extra senza nuovo ingrediente (documentazione estemporanea della produzione).
    @discardableResult
    func addExtraPhoto(
        batch: ProduzioneBatch,
        photoData: Data,
        user: LocalUser,
        modelContext: ModelContext
    ) throws -> ProductImage {
        guard batch.status == .inCorso else {
            throw NSError(domain: "IngredienteTracciatoService", code: 1, userInfo: [NSLocalizedDescriptionKey: "La produzione non è più modificabile."])
        }
        guard !photoData.isEmpty else { throw LabelLotError.invalidImage }
        let photoId = UUID()
        let stored = try LottoFotoImageStorage.save(
            photoData: photoData,
            restaurantId: batch.restaurantId,
            lottoFotoId: photoId
        )
        let inline = StoredImageCompression.preparedForStorage(photoData) ?? photoData
        let image = ProductImage(
            id: photoId,
            receivedItemId: nil,
            produzioneBatchId: batch.id,
            imageData: inline,
            localPath: stored.originalPath,
            type: .receiptOptional,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name
        )
        modelContext.insert(image)
        try modelContext.save()
        KitchenProcessNotifications.postRecordsDidChange()
        return image
    }

    /// Ingrediente extra non in ricetta: stesso flusso foto, nome libero.
    @discardableResult
    func appendExtraIngredient(
        batch: ProduzioneBatch,
        photoData: Data,
        ingredientName: String,
        supplierLot: String?,
        user: LocalUser,
        modelContext: ModelContext
    ) async throws -> IngredienteTracciato {
        let trace = try await appendFromPhoto(
            batch: batch,
            photoData: photoData,
            ingredientNameHint: ingredientName,
            user: user,
            modelContext: modelContext
        )
        try assignIngredientManually(
            ingredient: trace,
            name: ingredientName,
            modelContext: modelContext
        )
        if let supplierLot {
            try confirmLot(ingredient: trace, editedLot: supplierLot, modelContext: modelContext)
        }
        return trace
    }

    func assignIngredientManually(
        ingredient: IngredienteTracciato,
        option: RecipeIngredientOption,
        modelContext: ModelContext
    ) throws {
        try assignIngredientManually(
            ingredient: ingredient,
            name: option.name,
            productTemplateId: option.productTemplateId,
            modelContext: modelContext
        )
    }

    func assignIngredientManually(
        ingredient: IngredienteTracciato,
        name: String,
        productTemplateId: UUID? = nil,
        modelContext: ModelContext
    ) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "IngredienteTracciatoService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Seleziona la materia prima."])
        }
        ingredient.ingredientNameAssigned = trimmed
        ingredient.productTemplateId = productTemplateId
        ingredient.stato = resolveStateAfterIngredientAssignment(
            lotCode: ingredient.lotCodeExtracted,
            hadLotRegistered: ingredient.lotRegisteredAt != nil
        )
        try modelContext.save()
    }

    func confirmLot(
        ingredient: IngredienteTracciato,
        editedLot: String,
        modelContext: ModelContext
    ) throws {
        let lot = editedLot.trimmingCharacters(in: .whitespacesAndNewlines)
        // Lotto fornitore opzionale: se manca si conferma comunque (prova = foto).
        ingredient.lotCodeExtracted = lot.nilIfEmpty
        ingredient.lotRegisteredAt = Date()
        ingredient.stato = resolveStateAfterLotRegistration(
            ingredientName: ingredient.ingredientNameAssigned,
            lotCode: lot.nilIfEmpty
        )
        try modelContext.save()
    }

    // MARK: - Pipeline interna

    private func applyCaptureOutcome(
        _ outcome: ProductionLotCaptureOutcome,
        to trace: IngredienteTracciato
    ) {
        trace.ocrRawText = outcome.rawText.nilIfEmpty
        trace.ocrConfidence = outcome.confidence
        trace.lotCodeExtracted = outcome.lotCode
        // Solo lotto da OCR: l'alimento in ingresso si assegna sempre manualmente.
        trace.ingredientNameAssigned = nil
        trace.productTemplateId = nil
        trace.ingredientNameHint = nil

        if let lot = outcome.lotCode {
            trace.lotRegisteredAt = Date()
            trace.stato = .lottoRegistrato
        } else if outcome.rawText.isEmpty {
            trace.stato = .richiedeLotto
        } else {
            trace.stato = .richiedeLotto
        }
    }

    private func resolveStateAfterLotRegistration(ingredientName: String?, lotCode: String?) -> IngredienteTracciatoStato {
        let hasIngredient = ingredientName?.nilIfEmpty != nil
        // Lotto opzionale: dopo conferma (anche senza testo) si può procedere.
        if hasIngredient { return .completo }
        return .lottoRegistrato
    }

    private func resolveStateAfterIngredientAssignment(lotCode: String?, hadLotRegistered: Bool) -> IngredienteTracciatoStato {
        _ = lotCode
        // Lotto non obbligatorio: bastano alimento assegnato e foto.
        if hadLotRegistered { return .completo }
        return .completo
    }

    private func expectedIngredientNames(for batch: ProduzioneBatch, modelContext: ModelContext) -> [String] {
        let recipeNames = recipeIngredients(for: batch, modelContext: modelContext)
        if !recipeNames.isEmpty { return recipeNames }
        return fetchTemplateNames(restaurantId: batch.restaurantId, modelContext: modelContext)
    }

    private func fetchTemplateNames(restaurantId: UUID, modelContext: ModelContext) -> [String] {
        let rid = restaurantId
        let descriptor = FetchDescriptor<ProductTemplate>(
            predicate: #Predicate<ProductTemplate> { $0.restaurantId == rid }
        )
        return ((try? modelContext.fetch(descriptor)) ?? []).map(\.name)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
