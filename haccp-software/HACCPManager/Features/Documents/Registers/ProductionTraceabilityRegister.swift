import Foundation

/// Registro unificato produzioni ↔ ingredienti (layout master-detail per ispezione ASL).
enum ProductionTraceabilityRegister {
    private static let ingredientChildPrefix = "↳ Ingrediente"

    struct IngredientLine {
        let dateOperator: String
        let foodDetail: String
        let lot: String
        let expiryDetail: String
    }

    struct MasterBlock {
        let dateOperator: String
        let productionDetail: String
        let lotDetail: String
        let expiryDetail: String
        let ingredients: [IngredientLine]
        let batchId: UUID?
    }

    struct GiacenzaRow {
        let registeredAt: String
        let product: String
        let supplier: String
        let lot: String
        let expiry: String
        let operatorName: String
    }

    static func masterBlocks(
        in interval: DateInterval,
        traceability: [TraceabilityRecord],
        productions: [Production],
        links: [TraceabilityLink],
        labels: [ProductionLabelRecord],
        batches: [ProduzioneBatch],
        ingredientiTracciati: [IngredienteTracciato],
        lottoLinks: [LottoFotoProductionLink],
        lottoFotos: [LottoFoto],
        df: DateFormatter
    ) -> [MasterBlock] {
        let traceById = Dictionary(uniqueKeysWithValues: traceability.map { ($0.id, $0) })
        let productionById = Dictionary(uniqueKeysWithValues: productions.map { ($0.id, $0) })
        let lottoById = Dictionary(uniqueKeysWithValues: lottoFotos.map { ($0.id, $0) })
        let dayFormatter = dayOnlyFormatter()

        let scopedBatches = batches
            .filter { interval.contains($0.producedAt) }
            .sorted { $0.producedAt > $1.producedAt }

        var blocks: [MasterBlock] = []

        for batch in scopedBatches {
            let label = matchingLabel(for: batch, labels: labels)
            let outputRecord = traceability.first { $0.produzioneBatchId == batch.id }

            let internalLot = formattedBatchLot(label?.lotCode ?? batch.batchCode)
            let ingredientRecords = linkedIngredientRecords(
                for: batch,
                links: links,
                traceById: traceById,
                lottoLinks: lottoLinks
            )
            let production = productionById[batch.productionId]
            let dishExpiryDate = resolvedProductionExpiry(
                batch: batch,
                label: label,
                outputRecord: outputRecord,
                production: production,
                ingredientRecords: ingredientRecords
            )
            let dateLine = "\(dayFormatter.string(from: batch.producedAt)) · \(batch.createdByNameSnapshot)"
            let dishName = batch.isArchived
                ? "\(batch.productionNameSnapshot) [conservata in documenti — nascosta dallo storico]"
                : batch.productionNameSnapshot
            let ingredients = ingredientRecords.map {
                ingredientLine(
                    from: $0,
                    productionExpiry: dishExpiryDate,
                    lottoById: lottoById
                )
            }

            blocks.append(MasterBlock(
                dateOperator: dateLine,
                productionDetail: productionFoodLine(
                    name: dishName,
                    expiry: dishExpiryDate
                ),
                lotDetail: internalLot,
                expiryDetail: "—",
                ingredients: ingredients,
                batchId: batch.id
            ))
        }

        // Fallback: collegamenti lotto→produzione nel periodo senza batch esplicito in archivio.
        let batchProductionIds = Set(scopedBatches.map(\.productionId))
        let orphanLinks = links.filter { link in
            interval.contains(link.createdAt) && !batchProductionIds.contains(link.productionId)
        }
        let groupedOrphans = Dictionary(grouping: orphanLinks) { link -> String in
            let day = dayFormatter.string(from: link.createdAt)
            return "\(link.productionId.uuidString)|\(day)"
        }

        for (_, groupLinks) in groupedOrphans.sorted(by: { ($0.value.first?.createdAt ?? .distantPast) > ($1.value.first?.createdAt ?? .distantPast) }) {
            guard let first = groupLinks.first,
                  let production = productionById[first.productionId] else { continue }

            let orphanRecords = groupLinks.compactMap { traceById[$0.receivedItemId] }
            let dishExpiryDate = resolvedProductionExpiry(
                batch: nil,
                label: nil,
                outputRecord: nil,
                production: production,
                ingredientRecords: orphanRecords,
                referenceDate: groupLinks.map(\.createdAt).max() ?? first.createdAt
            )
            let ingredients = orphanRecords.map {
                ingredientLine(
                    from: $0,
                    productionExpiry: dishExpiryDate,
                    lottoById: lottoById
                )
            }

            let anchor = groupLinks.map(\.createdAt).max() ?? first.createdAt
            blocks.append(MasterBlock(
                dateOperator: "\(dayFormatter.string(from: anchor)) · \(production.name)",
                productionDetail: productionFoodLine(
                    name: production.name,
                    expiry: dishExpiryDate
                ),
                lotDetail: HACCPRegisterCopy.notAvailable,
                expiryDetail: "—",
                ingredients: ingredients,
                batchId: nil
            ))
        }

        return blocks.sorted { lhs, rhs in
            lhs.dateOperator > rhs.dateOperator
        }
    }

    static func giacenzaRows(
        in interval: DateInterval,
        traceability: [TraceabilityRecord],
        links: [TraceabilityLink],
        df: DateFormatter
    ) -> [GiacenzaRow] {
        let linkedIds = Set(links.map(\.receivedItemId))
        return traceability
            .filter { TraceabilityRecordSupport.isHubRecord($0) }
            .filter { interval.contains($0.receivedAt) && !linkedIds.contains($0.id) }
            .sorted { $0.receivedAt > $1.receivedAt }
            .map { record in
                GiacenzaRow(
                    registeredAt: df.string(from: record.receivedAt),
                    product: record.productName,
                    supplier: record.supplier.isEmpty ? HACCPRegisterCopy.notAvailable : record.supplier,
                    lot: record.lotCode.isEmpty ? HACCPRegisterCopy.notAvailable : record.lotCode,
                    expiry: record.expiryDate.map { formattedExpiry($0) } ?? HACCPRegisterCopy.notAvailable,
                    operatorName: record.createdByNameSnapshot
                )
            }
    }

    // MARK: - Private

    private static func linkedIngredientRecords(
        for batch: ProduzioneBatch,
        links: [TraceabilityLink],
        traceById: [UUID: TraceabilityRecord],
        lottoLinks: [LottoFotoProductionLink]
    ) -> [TraceabilityRecord] {
        var records: [TraceabilityRecord] = []
        var seenRecordIds = Set<UUID>()

        let productionLinks = links.filter { $0.productionId == batch.productionId }

        for link in productionLinks {
            guard let record = traceById[link.receivedItemId],
                  record.isIncomingIngredientLot,
                  seenRecordIds.insert(record.id).inserted else { continue }

            let recordBatchId = batchId(for: record, productionId: batch.productionId, lottoLinks: lottoLinks)
            guard recordBatchId == batch.id else { continue }

            records.append(record)
        }

        return records.sorted {
            $0.productName.localizedCaseInsensitiveCompare($1.productName) == .orderedAscending
        }
    }

    private static func resolvedProductionExpiry(
        batch: ProduzioneBatch?,
        label: ProductionLabelRecord?,
        outputRecord: TraceabilityRecord?,
        production: Production?,
        ingredientRecords: [TraceabilityRecord],
        referenceDate: Date? = nil
    ) -> Date? {
        if let batch, let internalExpiry = batch.internalExpiryAt {
            return internalExpiry
        }
        if let labelExpiry = label?.expiryDate {
            return labelExpiry
        }
        if let outputExpiry = outputRecord?.expiryDate {
            return outputExpiry
        }
        guard let production else { return nil }

        let anchor = referenceDate ?? batch?.producedAt ?? Date()
        let shelfDays = ScadenzaCalculator.shelfLifeDays(for: production)
        if ingredientRecords.isEmpty {
            return ScadenzaCalculator.productionExpiryDate(
                fromDays: shelfDays,
                referenceDate: anchor
            )
        }
        return ScadenzaCalculator.productionExpiryConstraint(
            shelfLifeDays: shelfDays,
            ingredientRecords: ingredientRecords,
            referenceDate: anchor
        ).suggestedExpiryDate
    }

    private static func resolvedIngredientExpiry(
        for record: TraceabilityRecord,
        lottoById: [UUID: LottoFoto]
    ) -> Date? {
        if let expiry = record.expiryDate {
            return expiry
        }
        guard let lottoId = record.lottoFotoId else { return nil }
        return lottoById[lottoId]?.expiryDate
    }

    private static func batchId(
        for record: TraceabilityRecord,
        productionId: UUID,
        lottoLinks: [LottoFotoProductionLink]
    ) -> UUID? {
        guard let lottoId = record.lottoFotoId else { return nil }
        return lottoLinks.first {
            $0.lottoFotoId == lottoId && $0.productionId == productionId
        }?.produzioneBatchId
    }

    private static func ingredientLine(
        from record: TraceabilityRecord,
        productionExpiry: Date?,
        lottoById: [UUID: LottoFoto]
    ) -> IngredientLine {
        let dayFormatter = dayOnlyFormatter()
        let dateOperator = [
            ingredientChildPrefix,
            "\(dayFormatter.string(from: record.receivedAt)) · \(record.createdByNameSnapshot)"
        ].joined(separator: "\n")

        let lot = record.lotCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let ingredientExpiry = resolvedIngredientExpiry(for: record, lottoById: lottoById)

        var foodLines = [
            ingredientFoodLine(
                name: record.productName,
                expiry: ingredientExpiry
            )
        ]
        let supplier = record.supplier.trimmingCharacters(in: .whitespacesAndNewlines)
        if !supplier.isEmpty {
            foodLines.append("Fornitore: \(supplier)")
        }

        return IngredientLine(
            dateOperator: dateOperator,
            foodDetail: foodLines.joined(separator: "\n"),
            lot: lot.isEmpty ? HACCPRegisterCopy.notAvailable : lot,
            expiryDetail: productionExpiryCell(productionExpiry)
        )
    }

    private static func productionFoodLine(name: String, expiry: Date?) -> String {
        let label = "Produzione: \(name)"
        guard let expiryText = formattedExpiryText(expiry) else { return label }
        return "\(label) (\(expiryText))"
    }

    private static func ingredientFoodLine(name: String, expiry: Date?) -> String {
        let label = "Alimento: \(name)"
        guard let expiryText = formattedExpiryText(expiry) else { return label }
        return "\(label) (\(expiryText))"
    }

    private static func productionExpiryCell(_ productionExpiry: Date?) -> String {
        guard let expiryText = formattedExpiryText(productionExpiry) else { return "—" }
        return "Produzione: \(expiryText)"
    }

    private static func formattedExpiryText(_ date: Date?) -> String? {
        guard let date else { return nil }
        let text = dayOnlyFormatter().string(from: date).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private static func formattedBatchLot(_ code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return HACCPRegisterCopy.notAvailable }
        if InternalLotCodeGenerator.isInternalLotCode(trimmed) || trimmed.hasPrefix("Batch #") {
            return trimmed
        }
        return trimmed.hasPrefix("#") ? trimmed : "#\(trimmed)"
    }

    private static func formattedExpiry(_ date: Date?, prefix: String = "") -> String {
        guard let text = formattedExpiryText(date) else { return HACCPRegisterCopy.notAvailable }
        return "\(prefix)\(text)"
    }

    private static func matchingLabel(
        for batch: ProduzioneBatch,
        labels: [ProductionLabelRecord]
    ) -> ProductionLabelRecord? {
        labels
            .filter { $0.productionId == batch.productionId && !$0.isArchived }
            .min(by: { lhs, rhs in
                abs(lhs.productionDate.timeIntervalSince(batch.producedAt))
                    < abs(rhs.productionDate.timeIntervalSince(batch.producedAt))
            })
    }

    private static func dayOnlyFormatter() -> DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "it_IT")
        df.calendar = Calendar(identifier: .gregorian)
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }
}
