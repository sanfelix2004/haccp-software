import Foundation
import SwiftData

struct TraceabilityService {
    func addRecord(
        restaurantId: UUID,
        productName: String,
        lotCode: String,
        supplier: String,
        receivedAt: Date,
        expiryDate: Date?,
        productionReference: String?,
        photoData: Data?,
        user: LocalUser,
        notes: String?,
        modelContext: ModelContext
    ) throws -> TraceabilityRecord {
        let trimmedProduct = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedProduct.isEmpty else {
            throw NSError(
                domain: "TraceabilityService",
                code: 4001,
                userInfo: [NSLocalizedDescriptionKey: "Il nome prodotto e obbligatorio."]
            )
        }

        let record = TraceabilityRecord(
            restaurantId: restaurantId,
            productName: trimmedProduct,
            lotCode: lotCode.trimmingCharacters(in: .whitespacesAndNewlines),
            supplier: supplier.trimmingCharacters(in: .whitespacesAndNewlines),
            receivedAt: receivedAt,
            expiryDate: expiryDate,
            productionReference: productionReference?.trimmingCharacters(in: .whitespacesAndNewlines),
            photoData: nil,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines),
            operatorSignature: user.name
        )
        modelContext.insert(record)
        modelContext.insert(
            TraceabilityLog(
                receivedItemId: record.id,
                actionType: .created,
                operatorName: user.name
            )
        )
        try modelContext.save()
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: restaurantId,
            user: user,
            modelContext: modelContext
        )
        return record
    }

    func markNonCompliant(
        record: TraceabilityRecord,
        note: String,
        correctiveAction: String,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAction = correctiveAction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty else {
            throw NSError(domain: "TraceabilityService", code: 4002, userInfo: [NSLocalizedDescriptionKey: "Inserisci il motivo della non conformità."])
        }
        guard !trimmedAction.isEmpty else {
            throw NSError(domain: "TraceabilityService", code: 4003, userInfo: [NSLocalizedDescriptionKey: "Inserisci l'azione correttiva obbligatoria."])
        }

        record.isNonCompliant = true
        record.nonComplianceNote = trimmedNote
        record.nonComplianceCorrectiveAction = trimmedAction
        record.productStatus = .rejected
        record.operationalClosedAt = Date()
        modelContext.insert(
            TraceabilityLog(
                receivedItemId: record.id,
                actionType: .nonCompliance,
                operatorName: user.name
            )
        )
        try modelContext.save()
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: record.restaurantId,
            user: user,
            modelContext: modelContext
        )
    }

    func markWithdrawn(
        record: TraceabilityRecord,
        kind: TraceabilityWithdrawalKind,
        note: String,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        guard record.canBeWithdrawn else {
            throw traceabilityError(
                4010,
                "Solo i lotti scaduti possono essere segnati come ritirati o scartati."
            )
        }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if kind.requiresNote, trimmedNote.isEmpty {
            throw traceabilityError(4011, "Indica la motivazione dello scarto.")
        }

        if record.productStatus != .expired,
           ProductExpiryEvaluator.shouldMarkSystemExpired(record) {
            record.productStatus = .expired
            modelContext.insert(
                TraceabilityLog(
                    receivedItemId: record.id,
                    actionType: .expired,
                    operatorName: "Sistema"
                )
            )
        }

        let stamp = Date().formatted(date: .abbreviated, time: .shortened)
        let closureLine = "[\(kind.label) \(stamp)]\(trimmedNote.isEmpty ? "" : " \(trimmedNote)")"
        if let existing = record.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !existing.isEmpty {
            record.notes = "\(existing)\n\(closureLine)"
        } else {
            record.notes = closureLine
        }

        let auditDetail = trimmedNote.isEmpty ? kind.label : "\(kind.label) — \(trimmedNote)"
        record.productStatus = .used
        record.operationalClosedAt = Date()
        modelContext.insert(
            TraceabilityLog(
                receivedItemId: record.id,
                actionType: .withdrawn,
                operatorName: user.name,
                detail: auditDetail
            )
        )

        DocumentMovementRecorder.recordLotClosedFromExpiryControl(
            record: record,
            outcomeLabel: kind.label,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            user: user,
            modelContext: modelContext
        )

        // Non soft-archiviare il batch: chiusura operativa ≠ nascondi dallo storico.

        try modelContext.save()
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: record.restaurantId,
            user: user,
            modelContext: modelContext
        )
    }

    /// Soft-delete: nasconde dalla UI operativa (uso Storia / nascondi MASTER).
    /// Per errori di inserimento da Tracciabilità usare `hardPurgeTraceabilityRecord`.
    func deleteRecord(
        record: TraceabilityRecord,
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        images: [ProductImage],
        user: LocalUser? = nil,
        modelContext: ModelContext
    ) throws {
        _ = links
        _ = logs
        _ = images
        if let user {
            try hardPurgeTraceabilityRecord(record: record, user: user, modelContext: modelContext)
        } else {
            // Senza utente: purge minimale senza sync report.
            let recordId = record.id
            ((try? modelContext.fetch(FetchDescriptor<TraceabilityLink>())) ?? [])
                .filter { $0.receivedItemId == recordId }
                .forEach { modelContext.delete($0) }
            ((try? modelContext.fetch(FetchDescriptor<TraceabilityLog>())) ?? [])
                .filter { $0.receivedItemId == recordId }
                .forEach { modelContext.delete($0) }
            ((try? modelContext.fetch(FetchDescriptor<ProductImage>())) ?? [])
                .filter { $0.receivedItemId == recordId }
                .forEach { modelContext.delete($0) }
            modelContext.delete(record)
            try modelContext.save()
        }
    }

    /// Elimina per errore di inserimento da Tracciabilità: cancellazione definitiva.
    /// Non scrive movimenti Documenti e non resta in PDF (diverso da Controllo scadenze).
    func deleteTraceabilityEntry(
        record: TraceabilityRecord,
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        images: [ProductImage],
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        _ = links
        _ = logs
        _ = images

        if record.isProductionBatchOutput, let batchId = record.produzioneBatchId {
            var batchDesc = FetchDescriptor<ProduzioneBatch>(
                predicate: #Predicate<ProduzioneBatch> { $0.id == batchId }
            )
            batchDesc.fetchLimit = 1
            if let batch = (try? modelContext.fetch(batchDesc))?.first {
                try hardPurgeProductionBatch(
                    batch: batch,
                    unlinkIncoming: true,
                    user: user,
                    modelContext: modelContext
                )
                return
            }
        }

        try hardPurgeTraceabilityRecord(record: record, user: user, modelContext: modelContext)
    }

    /// Corregge i dati di un alimento in ingresso o di un lotto produzione (errore di digitazione).
    func updateRecord(
        record: TraceabilityRecord,
        productName: String,
        lotCode: String,
        supplier: String,
        receivedAt: Date,
        expiryDate: Date?,
        notes: String?,
        user: LocalUser,
        modelContext: ModelContext,
        batchProducedAt: Date? = nil,
        batchNotes: String? = nil
    ) throws {
        let trimmedProduct = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedProduct.isEmpty else {
            throw traceabilityError(4012, "Il nome prodotto è obbligatorio.")
        }

        var changes: [String] = []
        func track(_ label: String, old: String, new: String) {
            if old != new { changes.append("\(label): «\(old)» → «\(new)»") }
        }

        let newLot = lotCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let newSupplier = supplier.trimmingCharacters(in: .whitespacesAndNewlines)
        let newNotesTrimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let newNotes = (newNotesTrimmed?.isEmpty == false) ? newNotesTrimmed : nil

        track("Prodotto", old: record.productName, new: trimmedProduct)
        track("Lotto", old: record.lotCode, new: newLot)
        track("Fornitore", old: record.supplier, new: newSupplier)

        let oldExpiry = record.expiryDate.map { Self.shortDate($0) } ?? "—"
        let newExpiry = expiryDate.map { Self.shortDate($0) } ?? "—"
        track("Scadenza", old: oldExpiry, new: newExpiry)

        if Self.shortDate(record.receivedAt) != Self.shortDate(receivedAt) {
            changes.append(
                "Data: «\(Self.shortDate(record.receivedAt))» → «\(Self.shortDate(receivedAt))»"
            )
        }

        record.productName = trimmedProduct
        record.lotCode = newLot
        record.supplier = newSupplier
        record.receivedAt = receivedAt
        record.expiryDate = expiryDate
        if expiryDate != nil {
            record.expirySource = .manualOperator
        }
        record.notes = newNotes

        // Allinea LottoFoto collegato (OCR / magazzino).
        if let lottoId = record.lottoFotoId {
            var descriptor = FetchDescriptor<LottoFoto>(
                predicate: #Predicate<LottoFoto> { $0.id == lottoId }
            )
            descriptor.fetchLimit = 1
            if let lotto = (try? modelContext.fetch(descriptor))?.first {
                lotto.testoLottoFinale = newLot.isEmpty ? lotto.testoLottoFinale : newLot
                lotto.alimentoIngressoNameSnapshot = trimmedProduct
                lotto.expiryDate = expiryDate
                lotto.expiryOverridden = true
                lotto.expiryFromLabel = false
            }
        }

        // Produzione finita: aggiorna anche il batch.
        var linkedProductionId: UUID?
        if let batchId = record.produzioneBatchId {
            var batchDescriptor = FetchDescriptor<ProduzioneBatch>(
                predicate: #Predicate<ProduzioneBatch> { $0.id == batchId }
            )
            batchDescriptor.fetchLimit = 1
            if let batch = (try? modelContext.fetch(batchDescriptor))?.first {
                linkedProductionId = batch.productionId
                if batch.productionNameSnapshot != trimmedProduct {
                    changes.append(
                        "Nome produzione: «\(batch.productionNameSnapshot)» → «\(trimmedProduct)»"
                    )
                    batch.productionNameSnapshot = trimmedProduct
                    record.productionReference = trimmedProduct
                }
                if let batchProducedAt, batch.producedAt != batchProducedAt {
                    changes.append(
                        "Produzione: «\(Self.shortDate(batch.producedAt))» → «\(Self.shortDate(batchProducedAt))»"
                    )
                    batch.producedAt = batchProducedAt
                    record.receivedAt = batchProducedAt
                }
                if batch.internalExpiryAt != expiryDate {
                    batch.internalExpiryAt = expiryDate
                }
                let trimmedBatchNotes = batchNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedBatchNotes = (trimmedBatchNotes?.isEmpty == false) ? trimmedBatchNotes : nil
                if batch.notes != normalizedBatchNotes {
                    batch.notes = normalizedBatchNotes
                }
            }
        }

        guard !changes.isEmpty else { return }

        modelContext.insert(
            TraceabilityLog(
                receivedItemId: record.id,
                productionId: linkedProductionId,
                actionType: .updated,
                operatorName: user.name,
                detail: changes.joined(separator: "; ")
            )
        )
        try modelContext.save()
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: record.restaurantId,
            user: user,
            modelContext: modelContext
        )
        KitchenProcessNotifications.postRecordsDidChange()
    }

    /// Elimina definitivamente una produzione errata da Tracciabilità.
    /// Gli alimenti in ingresso restano e vengono scollegati. Nessuna traccia Documenti.
    func deleteProductionBatchFromHub(
        batch: ProduzioneBatch,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        try hardPurgeProductionBatch(
            batch: batch,
            unlinkIncoming: true,
            user: user,
            modelContext: modelContext
        )
        KitchenProcessNotifications.postRecordsDidChange()
    }

    /// Elimina un gruppo produzione dall'hub per errore: cancellazione definitiva.
    /// Solo il lotto (batch) della card, non tutte le produzioni dello stesso piatto.
    func deleteProductionGroupFromHub(
        group: TraceabilityProductionArchiveGroup,
        batches: [ProduzioneBatch],
        finishedRecord: TraceabilityRecord?,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        try unlinkIncomingLots(
            productionId: group.productionId,
            batchId: group.batchId,
            modelContext: modelContext,
            writeAuditLogs: false
        )

        if let batchId = group.batchId,
           let batch = batches.first(where: { $0.id == batchId }) {
            try hardPurgeProductionBatch(
                batch: batch,
                unlinkIncoming: false,
                user: user,
                modelContext: modelContext
            )
        } else if let finishedRecord {
            try hardPurgeTraceabilityRecord(record: finishedRecord, user: user, modelContext: modelContext)
        } else {
            // Legacy senza batchId: solo l'ultimo batch del piatto.
            if let latest = batches
                .filter({ $0.productionId == group.productionId })
                .max(by: { $0.producedAt < $1.producedAt }) {
                try hardPurgeProductionBatch(
                    batch: latest,
                    unlinkIncoming: false,
                    user: user,
                    modelContext: modelContext
                )
            }
        }

        KitchenProcessNotifications.postRecordsDidChange()
    }

    /// Cancellazione definitiva di un lotto (errore di inserimento). Non resta in Storia né Documenti.
    func hardPurgeTraceabilityRecord(
        record: TraceabilityRecord,
        user: LocalUser,
        modelContext: ModelContext,
        deleteLinkedLottoFoto: Bool = true
    ) throws {
        let recordId = record.id
        let restaurantId = record.restaurantId
        let lotCode = record.lotCode

        let links = ((try? modelContext.fetch(FetchDescriptor<TraceabilityLink>())) ?? [])
            .filter { $0.receivedItemId == recordId }
        links.forEach { modelContext.delete($0) }

        if let lottoId = record.lottoFotoId {
            let lottoLinks = ((try? modelContext.fetch(FetchDescriptor<LottoFotoProductionLink>())) ?? [])
                .filter { $0.lottoFotoId == lottoId }
            lottoLinks.forEach { modelContext.delete($0) }
        }

        let logs = ((try? modelContext.fetch(FetchDescriptor<TraceabilityLog>())) ?? [])
            .filter { $0.receivedItemId == recordId }
        logs.forEach { modelContext.delete($0) }

        let images = ((try? modelContext.fetch(FetchDescriptor<ProductImage>())) ?? [])
            .filter { $0.receivedItemId == recordId }
        images.forEach { modelContext.delete($0) }

        if deleteLinkedLottoFoto, let lottoId = record.lottoFotoId {
            var lottoDesc = FetchDescriptor<LottoFoto>(predicate: #Predicate { $0.id == lottoId })
            lottoDesc.fetchLimit = 1
            if let lotto = (try? modelContext.fetch(lottoDesc))?.first {
                LottoFotoImageStorage.deleteFiles(
                    originalPath: lotto.localPath,
                    thumbnailPath: lotto.thumbnailPath
                )
                modelContext.delete(lotto)
            }
        }

        purgeRelatedLabels(
            restaurantId: restaurantId,
            traceabilityRecordId: recordId,
            lotCode: lotCode,
            modelContext: modelContext
        )
        purgeDocumentMovements(entityIds: [recordId], restaurantId: restaurantId, modelContext: modelContext)

        modelContext.delete(record)
        try modelContext.save()
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: restaurantId,
            user: user,
            modelContext: modelContext
        )
        KitchenProcessNotifications.postRecordsDidChange()
    }

    /// Cancellazione definitiva di un batch produzione (errore). Ingredienti in ingresso non cancellati.
    func hardPurgeProductionBatch(
        batch: ProduzioneBatch,
        unlinkIncoming: Bool,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        let restaurantId = batch.restaurantId
        let batchId = batch.id

        if unlinkIncoming {
            try unlinkIncomingLots(
                productionId: batch.productionId,
                batchId: batch.id,
                modelContext: modelContext,
                writeAuditLogs: false
            )
        }

        let tracked = ((try? modelContext.fetch(FetchDescriptor<IngredienteTracciato>())) ?? [])
            .filter { $0.produzioneBatchId == batchId }
        tracked.forEach { modelContext.delete($0) }

        let lottoLinks = ((try? modelContext.fetch(FetchDescriptor<LottoFotoProductionLink>())) ?? [])
            .filter { $0.produzioneBatchId == batchId || ($0.produzioneBatchId == nil && $0.productionId == batch.productionId) }
        lottoLinks.forEach { modelContext.delete($0) }

        var purgedEntityIds: [UUID] = [batchId]
        let outputs = ((try? modelContext.fetch(FetchDescriptor<TraceabilityRecord>())) ?? [])
            .filter { $0.produzioneBatchId == batchId }
        for output in outputs {
            let outputId = output.id
            purgedEntityIds.append(outputId)
            ((try? modelContext.fetch(FetchDescriptor<TraceabilityLink>())) ?? [])
                .filter { $0.receivedItemId == outputId }
                .forEach { modelContext.delete($0) }
            ((try? modelContext.fetch(FetchDescriptor<TraceabilityLog>())) ?? [])
                .filter { $0.receivedItemId == outputId }
                .forEach { modelContext.delete($0) }
            ((try? modelContext.fetch(FetchDescriptor<ProductImage>())) ?? [])
                .filter { $0.receivedItemId == outputId || $0.produzioneBatchId == batchId }
                .forEach { modelContext.delete($0) }
            purgeRelatedLabels(
                restaurantId: restaurantId,
                traceabilityRecordId: outputId,
                lotCode: output.lotCode.isEmpty ? batch.batchCode : output.lotCode,
                modelContext: modelContext
            )
            modelContext.delete(output)
        }

        ((try? modelContext.fetch(FetchDescriptor<ProductImage>())) ?? [])
            .filter { $0.produzioneBatchId == batchId }
            .forEach { modelContext.delete($0) }

        purgeRelatedLabels(
            restaurantId: restaurantId,
            traceabilityRecordId: nil,
            lotCode: batch.batchCode,
            modelContext: modelContext
        )
        purgeDocumentMovements(entityIds: purgedEntityIds, restaurantId: restaurantId, modelContext: modelContext)

        modelContext.delete(batch)
        try modelContext.save()
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: restaurantId,
            user: user,
            modelContext: modelContext
        )
    }

    /// Rimuove movimenti Documenti legati all’entità (niente traccia residua dopo errore).
    private func purgeDocumentMovements(
        entityIds: [UUID],
        restaurantId: UUID,
        modelContext: ModelContext
    ) {
        guard !entityIds.isEmpty else { return }
        let idSet = Set(entityIds)
        let movements = ((try? modelContext.fetch(FetchDescriptor<HACCPDocumentMovement>())) ?? [])
            .filter { $0.restaurantId == restaurantId && idSet.contains($0.entityId) }
        movements.forEach { modelContext.delete($0) }
    }

    private func purgeRelatedLabels(
        restaurantId: UUID,
        traceabilityRecordId: UUID?,
        lotCode: String?,
        modelContext: ModelContext
    ) {
        let labels = ((try? modelContext.fetch(FetchDescriptor<ProductionLabelRecord>())) ?? [])
            .filter { $0.restaurantId == restaurantId }
        let trimmedLot = lotCode?.trimmingCharacters(in: .whitespacesAndNewlines)

        for label in labels {
            if let traceabilityRecordId, label.traceabilityRecordId == traceabilityRecordId {
                modelContext.delete(label)
                continue
            }
            if let trimmedLot, !trimmedLot.isEmpty,
               let labelLot = label.lotCode?.trimmingCharacters(in: .whitespacesAndNewlines),
               labelLot == trimmedLot {
                modelContext.delete(label)
            }
        }
    }

    /// Scollega gli alimenti in ingresso da una produzione (i lotti restano disponibili).
    func unlinkIncomingLots(
        productionId: UUID,
        batchId: UUID?,
        modelContext: ModelContext,
        writeAuditLogs: Bool = true
    ) throws {
        let allLinks = ((try? modelContext.fetch(FetchDescriptor<TraceabilityLink>())) ?? [])
        let lottoLinks = ((try? modelContext.fetch(FetchDescriptor<LottoFotoProductionLink>())) ?? [])
        let records = ((try? modelContext.fetch(FetchDescriptor<TraceabilityRecord>())) ?? [])
            .filter { !$0.isArchived }
        let productions = ((try? modelContext.fetch(FetchDescriptor<Production>())) ?? [])
        let productionsById = Dictionary(uniqueKeysWithValues: productions.map { ($0.id, $0) })
        let recordsById = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })

        var deletedLottoLinkIds = Set<UUID>()
        for link in lottoLinks where link.productionId == productionId {
            let batchMatches: Bool = {
                guard let batchId else { return true }
                return link.produzioneBatchId == batchId
            }()
            guard batchMatches else { continue }
            modelContext.delete(link)
            deletedLottoLinkIds.insert(link.id)
        }

        let remainingLottoLinks = lottoLinks.filter { !deletedLottoLinkIds.contains($0.id) }
        let linksToRemove = allLinks.filter { link in
            guard link.productionId == productionId else { return false }
            guard let batchId else { return true }
            if let linkBatch = link.produzioneBatchId {
                return linkBatch == batchId
            }
            // Legacy senza batch: rimuovi solo se il lotto foto era collegato a questo batch.
            guard let record = recordsById[link.receivedItemId],
                  let lottoId = record.lottoFotoId else { return false }
            return lottoLinks.contains {
                deletedLottoLinkIds.contains($0.id) && $0.lottoFotoId == lottoId
            }
        }
        let affectedRecordIds = Set(linksToRemove.map(\.receivedItemId))
            .union(records.compactMap { record -> UUID? in
                guard let lottoId = record.lottoFotoId else { return nil }
                let wasLinked = lottoLinks.contains {
                    $0.lottoFotoId == lottoId
                        && $0.productionId == productionId
                        && deletedLottoLinkIds.contains($0.id)
                }
                return wasLinked ? record.id : nil
            })

        for link in linksToRemove {
            modelContext.delete(link)
        }

        let removedLinkIds = Set(linksToRemove.map(\.id))
        let survivingLinks = allLinks.filter { !removedLinkIds.contains($0.id) }

        for recordId in affectedRecordIds {
            guard let record = recordsById[recordId] else { continue }

            let stillLinkedViaLotto: Bool = {
                guard let lottoId = record.lottoFotoId else { return false }
                return remainingLottoLinks.contains {
                    $0.lottoFotoId == lottoId && $0.productionId == productionId
                }
            }()
            if stillLinkedViaLotto { continue }

            var remainingProductionIds = Set(
                survivingLinks
                    .filter { $0.receivedItemId == recordId }
                    .map(\.productionId)
            )
            if let lottoId = record.lottoFotoId {
                for link in remainingLottoLinks where link.lottoFotoId == lottoId {
                    remainingProductionIds.insert(link.productionId)
                }
            }
            let names = remainingProductionIds
                .compactMap { productionsById[$0]?.name }
                .sorted()
            record.productionReference = names.isEmpty ? nil : names.joined(separator: ", ")

            if writeAuditLogs {
                modelContext.insert(
                    TraceabilityLog(
                        receivedItemId: record.id,
                        productionId: productionId,
                        actionType: .updated,
                        operatorName: "Sistema",
                        detail: "Scollegato dalla produzione (eliminazione errore)"
                    )
                )
            }
        }

        try modelContext.save()
    }

    private static func shortDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    func addImage(
        to record: TraceabilityRecord,
        imageData: Data,
        type: ProductImageType,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        modelContext.insert(
            ProductImage(
                receivedItemId: record.id,
                imageData: StoredImageCompression.preparedForStorage(imageData),
                localPath: nil,
                type: type,
                createdByUserId: user.id,
                createdByNameSnapshot: user.name
            )
        )
        try modelContext.save()
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: record.restaurantId,
            user: user,
            modelContext: modelContext
        )
    }

    func exportTraceabilityReport(
        records: [TraceabilityRecord],
        links: [TraceabilityLink],
        productions: [Production]
    ) -> String {
        let productionMap = Dictionary(uniqueKeysWithValues: productions.map { ($0.id, $0.name) })
        let header = "prodotto,fornitore,lotto,stato,data_ricezione,data_scadenza,produzioni"
        let rows = records.map { record in
            let linkedNames = links
                .filter { $0.receivedItemId == record.id }
                .compactMap { productionMap[$0.productionId] }
                .joined(separator: " | ")
            return [
                csvCell(record.productName),
                csvCell(record.supplier),
                csvCell(record.lotCode),
                csvCell(record.productStatus.label),
                csvCell(record.receivedAt.formatted(date: .abbreviated, time: .shortened)),
                csvCell(record.expiryDate?.formatted(date: .abbreviated, time: .omitted) ?? ""),
                csvCell(linkedNames)
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private func csvCell(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func traceabilityError(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "TraceabilityService", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
