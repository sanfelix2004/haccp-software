import Foundation
import SwiftData

struct LottoFotoService {
    private let capturePipeline = ProductionLotCapturePipeline()
    private let batchService = ProduzioneBatchService()
    private let productionLibraryService = ProductionLibraryService()
    private let expiryTracking = ExpiryTrackingService()

    // MARK: - Query

    func sessionItems(
        sessionId: UUID,
        modelContext: ModelContext
    ) -> [LottoFoto] {
        let sid = sessionId
        var descriptor = FetchDescriptor<LottoFoto>(
            predicate: #Predicate<LottoFoto> { !$0.isArchived },
            sortBy: [SortDescriptor(\LottoFoto.dataScatto)]
        )
        return ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.traceabilitySessionId == sid }
    }

    /// Tutte le foto etichetta confermate per il ristorante (più recenti prima).
    func allPhotos(restaurantId: UUID, modelContext: ModelContext) -> [LottoFoto] {
        let rid = restaurantId
        var descriptor = FetchDescriptor<LottoFoto>(
            predicate: #Predicate<LottoFoto> { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\LottoFoto.dataScatto, order: .reverse)]
        )
        descriptor.fetchLimit = 2_000
        return ((try? modelContext.fetch(descriptor)) ?? [])
            .filter(\.isConfirmed)
    }

    func linkedProductionNames(for lottoFotoId: UUID, productions: [Production], modelContext: ModelContext) -> [String] {
        let ids = linkedProductionIds(for: lottoFotoId, modelContext: modelContext)
        return productions
            .filter { ids.contains($0.id) }
            .map(\.name)
            .sorted()
    }

    func traceabilityRecord(for lotto: LottoFoto, modelContext: ModelContext) -> TraceabilityRecord? {
        let lottoId = lotto.id
        let descriptor = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate<TraceabilityRecord> { $0.lottoFotoId == lottoId }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    func links(for lottoFotoId: UUID, modelContext: ModelContext) -> [LottoFotoProductionLink] {
        let descriptor = FetchDescriptor<LottoFotoProductionLink>()
        return ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.lottoFotoId == lottoFotoId }
    }

    func linkedProductionIds(for lottoFotoId: UUID, modelContext: ModelContext) -> Set<UUID> {
        Set(links(for: lottoFotoId, modelContext: modelContext).map(\.productionId))
    }

    /// Sessioni camera con lotti confermati ma non ancora associati a un piatto.
    func openSessions(restaurantId: UUID, modelContext: ModelContext) -> [TraceabilityOpenSession] {
        let rid = restaurantId
        let lottoDescriptor = FetchDescriptor<LottoFoto>(
            predicate: #Predicate<LottoFoto> { $0.restaurantId == rid && !$0.isArchived }
        )
        let lottoFotos = ((try? modelContext.fetch(lottoDescriptor)) ?? [])
            .filter { $0.isConfirmed && $0.traceabilitySessionId != nil }

        let allLinks = (try? modelContext.fetch(FetchDescriptor<LottoFotoProductionLink>())) ?? []
        let linkedLottoIds = Set(allLinks.map(\.lottoFotoId))

        let grouped = Dictionary(
            grouping: lottoFotos.compactMap { lotto -> (UUID, LottoFoto)? in
                guard let sessionId = lotto.traceabilitySessionId else { return nil }
                return (sessionId, lotto)
            },
            by: \.0
        )
        return grouped.compactMap { sessionId, pairs in
            let items = pairs.map(\.1)
            let unlinked = items.filter { !linkedLottoIds.contains($0.id) }
            guard !unlinked.isEmpty else { return nil }
            let names = unlinked.compactMap(\.alimentoIngressoNameSnapshot)
            let startedAt = items.map(\.dataScatto).min() ?? Date()
            return TraceabilityOpenSession(
                id: sessionId,
                itemCount: unlinked.count,
                previewNames: names,
                startedAt: startedAt
            )
        }
        .sorted { $0.startedAt > $1.startedAt }
    }

    /// Crea `TraceabilityRecord` mancanti per lotti già confermati (backfill).
    func ensureArchiveRecords(restaurantId: UUID, modelContext: ModelContext) {
        let rid = restaurantId
        let descriptor = FetchDescriptor<LottoFoto>(
            predicate: #Predicate<LottoFoto> { $0.restaurantId == rid && !$0.isArchived }
        )
        let lottoFotos = ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.isConfirmed }
        guard !lottoFotos.isEmpty else { return }

        let recordDescriptor = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate<TraceabilityRecord> { $0.restaurantId == rid && !$0.isArchived }
        )
        let records = (try? modelContext.fetch(recordDescriptor)) ?? []
        var recordsByLottoId: [UUID: TraceabilityRecord] = [:]
        for record in records {
            if let lottoId = record.lottoFotoId {
                recordsByLottoId[lottoId] = record
            }
        }

        var didChange = false
        for lotto in lottoFotos {
            if let record = recordsByLottoId[lotto.id] {
                if record.lottoFotoId == nil {
                    record.lottoFotoId = lotto.id
                    didChange = true
                }
            } else if (try? createArchiveRecord(for: lotto, template: nil, modelContext: modelContext)) != nil {
                didChange = true
            }
        }
        if didChange {
            modelContext.saveSafely(operation: "lotto-archive-backfill")
        }
    }

    // MARK: - Capture

    /// Crea subito la bozza foto senza attendere l'analisi AI (immagine già downsampled).
    func makePendingCapture(photoData: Data) -> PendingLottoCapture {
        let previewData = ImageProcessor.preparedJPEGData(
            from: photoData,
            maxPixel: PerformanceConfig.capturePreviewMaxPixelDimension,
            quality: PerformanceConfig.imageJPEGQuality
        ) ?? photoData
        return PendingLottoCapture(
            photoData: previewData,
            testoLottoOCR: nil,
            lotDraft: "",
            ocrRawText: nil,
            ocrConfidence: nil,
            isLotExtracting: true
        )
    }

    /// Analisi lotto in background (OCR locale + Groq in parallelo).
    func extractLot(from photoData: Data) async throws -> ProductionLotCaptureOutcome {
        guard !photoData.isEmpty else { throw LabelLotError.invalidImage }
        return try await capturePipeline.process(photoData: photoData, expectedIngredientNames: [])
    }

    func extractLotGroqOnly(from photoData: Data) async throws -> ProductionLotCaptureOutcome {
        guard !photoData.isEmpty else { throw LabelLotError.invalidImage }
        return try await capturePipeline.processGroqOnly(photoData: photoData, expectedIngredientNames: [])
    }

    func extractLotLocalPreview(from photoData: Data) async -> ProductionLotCaptureOutcome? {
        guard !photoData.isEmpty else { return nil }
        return await capturePipeline.processLocalPreview(photoData: photoData)
    }

    /// Elabora foto in modo sincrono (legacy / test).
    func processCapture(photoData: Data) async throws -> PendingLottoCapture {
        guard !photoData.isEmpty else { throw LabelLotError.invalidImage }
        let outcome = try await extractLot(from: photoData)
        return PendingLottoCapture(
            photoData: photoData,
            testoLottoOCR: outcome.lotCode,
            lotDraft: outcome.lotCode ?? "",
            ocrRawText: outcome.rawText.nilIfEmpty,
            ocrConfidence: outcome.confidence,
            labelExpiryDate: outcome.expiryDate,
            expiryFromLabel: outcome.isExpiryFromLabel,
            isLotExtracting: false
        )
    }

    /// Conferma scatto da Ricezione merci: collega lotto foto alla ricezione e al registro tracciabilità.
    @discardableResult
    func confirmCaptureFromReceipt(
        pending: PendingLottoCapture,
        template: ProductTemplate,
        supplier: String,
        expiryDate: Date?,
        expiryFromLabel: Bool,
        expiryUserEdited: Bool = false,
        acceptedDespiteExpired: Bool = false,
        receipt: RicezioneMerce,
        user: LocalUser,
        modelContext: ModelContext
    ) throws -> LottoFoto {
        let lotto = try confirmCapture(
            pending: pending,
            template: template,
            supplier: supplier,
            expiryDate: expiryDate,
            expiryFromLabel: expiryFromLabel,
            expiryUserEdited: expiryUserEdited,
            acceptedDespiteExpired: acceptedDespiteExpired,
            sessionId: receipt.id,
            user: user,
            modelContext: modelContext,
            receipt: receipt
        )
        return lotto
    }

    /// Conferma scatto: persiste metadati lotto + voce archivio (senza salvare foto su disco).
    @discardableResult
    func confirmCapture(
        pending: PendingLottoCapture,
        template: ProductTemplate,
        supplier: String,
        expiryDate: Date?,
        expiryFromLabel: Bool,
        expiryUserEdited: Bool = false,
        acceptedDespiteExpired: Bool = false,
        sessionId: UUID,
        user: LocalUser,
        modelContext: ModelContext,
        receipt: RicezioneMerce? = nil
    ) throws -> LottoFoto {
        let lotText = pending.lotDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pending.photoData.isEmpty else {
            throw NSError(
                domain: "LottoFotoService",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Foto non disponibile. Scatta di nuovo l'etichetta."]
            )
        }
        if SettingsStorageService.shared.haccp.lotEntryMandatory, lotText.isEmpty {
            throw NSError(
                domain: "LottoFotoService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Il codice lotto è obbligatorio."]
            )
        }

        let lottoId = UUID()

        let resolvedExpiry = pending.labelExpiryDate ?? expiryDate
        let resolvedFromLabel = (pending.expiryFromLabel || expiryFromLabel) && !expiryUserEdited
        let expirySource = ExpiryTrackingService.resolveIncomingSource(
            expiryFromLabel: resolvedFromLabel,
            expiryUserEdited: expiryUserEdited
        )

        let normalizedExpiry = resolvedExpiry.map { HACCPDateNormalizer.normalizedExpiry($0) }

        let lotto = LottoFoto(
            id: lottoId,
            restaurantId: template.restaurantId,
            localPath: "",
            thumbnailPath: nil,
            testoLottoOCR: pending.testoLottoOCR,
            testoLottoFinale: lotText.nilIfEmpty,
            dataScatto: Date(),
            alimentoIngressoID: template.id,
            alimentoIngressoNameSnapshot: template.name,
            expiryDate: normalizedExpiry,
            expiryOverridden: expiryUserEdited,
            expiryFromLabel: resolvedFromLabel,
            traceabilitySessionId: sessionId,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name
        )
        modelContext.insert(lotto)
        let record = try createArchiveRecord(
            for: lotto,
            template: template,
            supplier: supplier,
            receipt: receipt,
            modelContext: modelContext
        )
        if let normalizedExpiry {
            try expiryTracking.registerIncomingExpiry(
                on: record,
                expiryDate: normalizedExpiry,
                source: expirySource,
                operatorName: user.name,
                modelContext: modelContext,
                acceptedDespiteExpired: acceptedDespiteExpired
            )
        }
        try modelContext.save()
        modelContext.processPendingChanges()
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: template.restaurantId,
            user: user,
            modelContext: modelContext
        )
        return lotto
    }

    func delete(_ lotto: LottoFoto, modelContext: ModelContext) throws {
        if let record = traceabilityRecord(for: lotto, modelContext: modelContext) {
            let links = (try? modelContext.fetch(FetchDescriptor<TraceabilityLink>())) ?? []
            let logs = (try? modelContext.fetch(FetchDescriptor<TraceabilityLog>())) ?? []
            let images = (try? modelContext.fetch(FetchDescriptor<ProductImage>())) ?? []
            links.filter { $0.receivedItemId == record.id }.forEach { modelContext.delete($0) }
            logs.filter { $0.receivedItemId == record.id }.forEach { modelContext.delete($0) }
            images.filter { $0.receivedItemId == record.id }.forEach { modelContext.delete($0) }
            modelContext.delete(record)
        }

        let descriptor = FetchDescriptor<LottoFotoProductionLink>()
        let existingLinks = ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.lottoFotoId == lotto.id }
        for link in existingLinks {
            modelContext.delete(link)
        }
        LottoFotoImageStorage.deleteFiles(
            originalPath: lotto.localPath,
            thumbnailPath: lotto.thumbnailPath
        )
        modelContext.delete(lotto)
        try modelContext.save()
    }

    // MARK: - Associazione produzione (molti-a-molti)

    func associateWithProductions(
        lottoFotos: [LottoFoto],
        reusedRecords: [TraceabilityRecord] = [],
        productions: [Production],
        user: LocalUser,
        modelContext: ModelContext,
        productionShelfLifeDays: Int? = nil,
        ignoreIngredientConstraint: Bool = false
    ) throws {
        guard (!lottoFotos.isEmpty || !reusedRecords.isEmpty), !productions.isEmpty else {
            throw NSError(
                domain: "LottoFotoService",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Seleziona almeno un lotto e una produzione."]
            )
        }

        var traceabilityLinks = (try? modelContext.fetch(FetchDescriptor<TraceabilityLink>())) ?? []

        for production in productions {
            let batch = try batchService.startBatch(
                production: production,
                user: user,
                modelContext: modelContext
            )

            // 1. Associa i nuovi scatti via LottoFoto
            for lotto in lottoFotos {
                let link = LottoFotoProductionLink(
                    lottoFotoId: lotto.id,
                    productionId: production.id,
                    produzioneBatchId: batch.id
                )
                modelContext.insert(link)

                if let record = traceabilityRecord(for: lotto, modelContext: modelContext) {
                    try productionLibraryService.associate(
                        record: record,
                        production: production,
                        quantityUsed: nil,
                        operatorName: user.name,
                        links: traceabilityLinks,
                        modelContext: modelContext
                    )
                    traceabilityLinks = (try? modelContext.fetch(FetchDescriptor<TraceabilityLink>())) ?? traceabilityLinks
                }
            }

            // 2. Associa i record riutilizzati (sia con che senza LottoFoto)
            for record in reusedRecords {
                if let lottoId = record.lottoFotoId {
                    let link = LottoFotoProductionLink(
                        lottoFotoId: lottoId,
                        productionId: production.id,
                        produzioneBatchId: batch.id
                    )
                    modelContext.insert(link)
                }

                try productionLibraryService.associate(
                    record: record,
                    production: production,
                    quantityUsed: nil,
                    operatorName: user.name,
                    links: traceabilityLinks,
                    modelContext: modelContext
                )
                traceabilityLinks = (try? modelContext.fetch(FetchDescriptor<TraceabilityLink>())) ?? traceabilityLinks
            }

            // 3. Calcola la scadenza combinando tutti i record degli ingredienti
            let shelfDays = productionShelfLifeDays ?? production.defaultShelfLifeDays
            
            var ingredientRecords: [TraceabilityRecord] = []
            ingredientRecords += lottoFotos.compactMap {
                traceabilityRecord(for: $0, modelContext: modelContext)
            }
            ingredientRecords += reusedRecords
            
            // Rendi univoci per ID
            var uniqueIngredients: [TraceabilityRecord] = []
            var seenIds = Set<UUID>()
            for rec in ingredientRecords {
                if !seenIds.contains(rec.id) {
                    seenIds.insert(rec.id)
                    uniqueIngredients.append(rec)
                }
            }

            let constraint = ScadenzaCalculator.resolvedProductionExpiry(
                shelfLifeDays: shelfDays,
                ingredientRecords: uniqueIngredients,
                ignoreIngredientConstraint: ignoreIngredientConstraint
            )
            let internalExpiry = constraint.suggestedExpiryDate
            
            try batchService.completeBatch(
                batch: batch,
                internalExpiryAt: internalExpiry,
                ingredientCount: uniqueIngredients.count,
                user: user,
                modelContext: modelContext
            )
            _ = try expiryTracking.registerProductionExpiry(
                batch: batch,
                production: production,
                expiryDate: internalExpiry,
                shelfLifeDays: shelfDays,
                constraint: constraint,
                forcedCatalogDuration: ignoreIngredientConstraint,
                user: user,
                modelContext: modelContext
            )
        }

        try modelContext.save()
        
        let restaurantId = lottoFotos.first?.restaurantId ?? reusedRecords.first?.restaurantId
        if let restaurantId {
            HACCPArchiveSyncCoordinator.requestDeferredSync(
                restaurantId: restaurantId,
                user: user,
                modelContext: modelContext
            )
        }
    }

    // MARK: - Archivio tracciabilità

    @discardableResult
    private func createArchiveRecord(
        for lotto: LottoFoto,
        template: ProductTemplate?,
        supplier: String = "",
        receipt: RicezioneMerce? = nil,
        modelContext: ModelContext
    ) throws -> TraceabilityRecord {
        if let existing = traceabilityRecord(for: lotto, modelContext: modelContext) {
            applyReceiptLink(to: existing, receipt: receipt, lotto: lotto)
            return existing
        }

        let categoryRaw = template?.category.rawValue
        let receivedAt = receipt?.receivedAt ?? lotto.dataScatto
        let record = TraceabilityRecord(
            restaurantId: lotto.restaurantId,
            productName: lotto.alimentoIngressoNameSnapshot ?? "Alimento",
            lotCode: lotto.lotCode ?? "",
            supplier: supplier.trimmingCharacters(in: .whitespacesAndNewlines),
            source: receipt == nil ? .manual : .receipt,
            goodsReceiptId: receipt?.id,
            receivedAt: receivedAt,
            expiryDate: lotto.expiryDate,
            photoData: nil,
            createdAt: lotto.createdAt,
            createdByUserId: lotto.createdByUserId,
            createdByNameSnapshot: lotto.createdByNameSnapshot,
            operatorSignature: lotto.createdByNameSnapshot,
            lottoFotoId: lotto.id
        )
        if let categoryRaw {
            record.categoryRaw = categoryRaw
        }
        applyReceiptLink(to: record, receipt: receipt, lotto: lotto)
        modelContext.insert(record)
        modelContext.insert(
            TraceabilityLog(
                receivedItemId: record.id,
                actionType: .created,
                operatorName: lotto.createdByNameSnapshot,
                detail: receipt == nil ? nil : "Ricezione merci conforme"
            )
        )
        return record
    }

    private func applyReceiptLink(to record: TraceabilityRecord, receipt: RicezioneMerce?, lotto: LottoFoto) {
        guard let receipt else { return }
        record.goodsReceiptId = receipt.id
        record.source = .receipt
        record.goodsReceiptStatusRaw = receipt.statusRaw
        record.receivedAt = receipt.receivedAt
        if record.lottoFotoId == nil {
            record.lottoFotoId = lotto.id
        }
    }
}

struct PendingLottoCapture: Identifiable {
    let id = UUID()
    let photoData: Data
    var testoLottoOCR: String?
    var lotDraft: String
    var ocrRawText: String?
    var ocrConfidence: Double?
    var labelExpiryDate: Date?
    var expiryFromLabel = false
    var isLotExtracting: Bool = false
    var lotExtractionError: String?
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
