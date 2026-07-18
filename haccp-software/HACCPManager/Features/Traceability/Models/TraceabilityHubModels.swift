import Foundation
import SwiftUI
import SwiftData

// MARK: - Filtri hub

enum TraceabilityHubFilter: String, CaseIterable, Identifiable {
    case today = "Oggi"
    case unlinked = "Da associare"
    case critical = "Non conformi"
    case all = "Tutti"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .today: return "calendar"
        case .unlinked: return "link.badge.plus"
        case .critical: return "exclamationmark.triangle.fill"
        case .all: return "square.grid.2x2"
        }
    }
}

struct TraceabilityHubMetrics: Equatable {
    let total: Int
    let available: Int
    let unlinked: Int
    let critical: Int
    let todayCount: Int
}

struct TraceabilityOpenSession: Identifiable, Equatable {
    let id: UUID
    let itemCount: Int
    let previewNames: [String]
    let startedAt: Date
}

struct TraceabilityArchiveIngredientItem: Identifiable, Equatable {
    let id: UUID
    /// Lotto tracciabilità collegato; `nil` se l'ingrediente proviene solo da batch produzione.
    let recordId: UUID?
    let name: String
    let lotCode: String
    let supplier: String
    let receivedAt: Date
    /// Miniatura foto etichetta / NC (visibile in archivio).
    var photoData: Data? = nil
}

struct TraceabilityProductionArchiveGroup: Identifiable, Equatable {
    let id: String
    let productionId: UUID
    let productionName: String
    let batchId: UUID?
    /// Codice lotto interno (es. 20260718-01).
    let batchCode: String?
    let registeredAt: Date
    let ingredients: [TraceabilityArchiveIngredientItem]
    /// Foto del piatto finito (mai quella degli ingredienti in ingresso).
    var photoData: Data? = nil
}

// MARK: - Contesto display (indici pre-calcolati)

@MainActor
struct TraceabilityHubContext {
    let productionIdsByRecord: [UUID: Set<UUID>]
    let recordIdsByProduction: [UUID: Set<UUID>]
    let productionsById: [UUID: Production]
    let defrostByTrace: [UUID: [DefrostRecord]]
    let imagesByRecord: [UUID: [ProductImage]]
    let logsByRecord: [UUID: [TraceabilityLog]]
    private let allProductImages: [ProductImage]
    private let lottoFotoById: [UUID: LottoFoto]
    private let lottoLinksByFotoId: [UUID: [LottoFotoProductionLink]]
    private let recordsById: [UUID: TraceabilityRecord]
    private let recordByLottoFotoId: [UUID: TraceabilityRecord]
    private let batches: [ProduzioneBatch]
    private let ingredientiTracciati: [IngredienteTracciato]

    init(store: TraceabilityDataStore) {
        self.init(
            records: store.records,
            productions: store.productions,
            links: store.links,
            lottoProductionLinks: store.lottoProductionLinks,
            batches: store.batches,
            ingredientiTracciati: store.ingredientiTracciati,
            logs: store.logs,
            images: store.images,
            lottoFotos: store.lottoFotos,
            defrostRecords: store.defrostRecords,
            productionOutputRecords: store.productionOutputRecords
        )
    }

    init(
        records: [TraceabilityRecord],
        productions: [Production],
        links: [TraceabilityLink],
        lottoProductionLinks: [LottoFotoProductionLink],
        batches: [ProduzioneBatch] = [],
        ingredientiTracciati: [IngredienteTracciato] = [],
        logs: [TraceabilityLog] = [],
        images: [ProductImage] = [],
        lottoFotos: [LottoFoto] = [],
        defrostRecords: [DefrostRecord] = [],
        productionOutputRecords: [TraceabilityRecord] = []
    ) {
        productionsById = HACCPSafeParse.dictionary(productions.map { ($0.id, $0) })
        recordsById = HACCPSafeParse.dictionary(
            (records + productionOutputRecords).map { ($0.id, $0) }
        )
        lottoFotoById = HACCPSafeParse.dictionary(lottoFotos.map { ($0.id, $0) })
        var recordByLotto: [UUID: TraceabilityRecord] = [:]
        for record in records {
            if let lottoId = record.lottoFotoId {
                recordByLotto[lottoId] = record
            }
        }
        recordByLottoFotoId = recordByLotto
        var lottoLinkMap: [UUID: [LottoFotoProductionLink]] = [:]
        for link in lottoProductionLinks {
            lottoLinkMap[link.lottoFotoId, default: []].append(link)
        }
        lottoLinksByFotoId = lottoLinkMap
        self.batches = batches.filter { !$0.isArchived }
        self.ingredientiTracciati = ingredientiTracciati
        var prodMap: [UUID: Set<UUID>] = [:]
        for link in links {
            prodMap[link.receivedItemId, default: []].insert(link.productionId)
        }
        for lottoLink in lottoProductionLinks {
            if let record = recordByLottoFotoId[lottoLink.lottoFotoId] {
                prodMap[record.id, default: []].insert(lottoLink.productionId)
            }
        }
        productionIdsByRecord = prodMap

        var recordsByProd: [UUID: Set<UUID>] = [:]
        for link in links {
            recordsByProd[link.productionId, default: []].insert(link.receivedItemId)
        }
        recordIdsByProduction = recordsByProd

        var defrostMap: [UUID: [DefrostRecord]] = [:]
        for defrost in defrostRecords {
            if let traceId = defrost.traceabilityItemId {
                defrostMap[traceId, default: []].append(defrost)
            }
        }
        defrostByTrace = defrostMap

        var imageMap: [UUID: [ProductImage]] = [:]
        for image in images {
            guard let receivedItemId = image.receivedItemId else { continue }
            imageMap[receivedItemId, default: []].append(image)
        }
        imagesByRecord = imageMap
        allProductImages = images

        var logMap: [UUID: [TraceabilityLog]] = [:]
        for log in logs {
            logMap[log.receivedItemId, default: []].append(log)
        }
        logsByRecord = logMap
    }

    func metrics(for records: [TraceabilityRecord]) -> TraceabilityHubMetrics {
        var available = 0
        var unlinked = 0
        var critical = 0
        var todayCount = 0

        for record in records {
            if Calendar.current.isDateInToday(record.createdAt) {
                todayCount += 1
            }
            if record.isNonCompliant || record.productStatus == .rejected {
                critical += 1
            }
            let linked = (productionIdsByRecord[record.id]?.count ?? 0) > 0
            let actionable = isActionable(record)
            if actionable && !linked && record.isIncomingIngredientLot {
                unlinked += 1
            }
            if record.productStatus == .available {
                available += 1
            }
        }
        return TraceabilityHubMetrics(
            total: records.count,
            available: available,
            unlinked: unlinked,
            critical: critical,
            todayCount: todayCount
        )
    }

    func filteredRecords(
        _ records: [TraceabilityRecord],
        filter: TraceabilityHubFilter,
        searchText: String
    ) -> [TraceabilityRecord] {
        let tokens = TraceabilityArchiveSearch.tokens(from: searchText)

        return records.filter { record in
            guard record.isIncomingIngredientLot else { return false }

            let searchOk = tokens.isEmpty || matchesSearch(record, tokens: tokens)
            guard searchOk else { return false }

            switch filter {
            case .all:
                return true
            case .unlinked:
                return isActionable(record) && (productionIdsByRecord[record.id]?.isEmpty ?? true)
            case .critical:
                return record.isNonCompliant || record.productStatus == .rejected
            case .today:
                return Calendar.current.isDateInToday(record.createdAt)
            }
        }
    }

    func display(for record: TraceabilityRecord) -> TraceabilityRecordDisplay {
        let actionable = isActionable(record)
        let productionCount = productionIdsByRecord[record.id]?.count ?? 0
        let linkedIngredientCount = ingredientCount(for: record)
        let (statusLabel, badgeStyle) = traceabilityStatus(
            for: record,
            productionCount: productionCount,
            actionable: actionable
        )

        return TraceabilityRecordDisplay(
            recordId: record.id,
            productName: record.productName,
            lot: lotDisplay(for: record),
            supplier: supplierDisplay(for: record),
            receivedAt: record.receivedAt,
            category: categoryDisplay(for: record),
            statusLabel: statusLabel,
            badgeStyle: badgeStyle,
            productionCount: productionCount,
            linkedIngredientCount: linkedIngredientCount,
            defrostCount: defrostByTrace[record.id]?.count ?? 0,
            isActionable: actionable,
            needsProductionLink: actionable && productionCount == 0 && record.isIncomingIngredientLot,
            isProductionLot: record.isProductionBatchOutput
                || InternalLotCodeGenerator.isInternalLotCode(record.lotCode)
        )
    }

    func image(for record: TraceabilityRecord) -> UIImage? {
        if let bytes = photoBytes(for: record), let image = UIImage(data: bytes) {
            return image
        }
        return nil
    }

    /// Byte foto per UI (card / dettaglio / archivio).
    func photoBytes(for record: TraceabilityRecord) -> Data? {
        ProductImageBytesResolver.resolve(
            record: record,
            images: imagesForPhotoLookup(record),
            lottoFotos: Array(lottoFotoById.values)
        )
    }

    func allPhotoBytes(for record: TraceabilityRecord) -> [Data] {
        ProductImageBytesResolver.allPhotos(
            record: record,
            images: imagesForPhotoLookup(record),
            lottoFotos: Array(lottoFotoById.values)
        )
    }

    private func imagesForPhotoLookup(_ record: TraceabilityRecord) -> [ProductImage] {
        var result = imagesByRecord[record.id] ?? []
        if let goodsId = record.goodsReceiptId {
            let byGoods = allProductImages.filter { $0.goodsReceiptId == goodsId && !$0.isArchived }
            for image in byGoods where !result.contains(where: { $0.id == image.id }) {
                result.append(image)
            }
        }
        return result
    }

    func associatedProductions(for record: TraceabilityRecord) -> [Production] {
        let ids = productionIdsByRecord[record.id] ?? []
        return ids.compactMap { productionsById[$0] }.sorted { $0.name < $1.name }
    }

    func defrostRecords(for record: TraceabilityRecord) -> [DefrostRecord] {
        defrostByTrace[record.id] ?? []
    }

    func auditLogs(for record: TraceabilityRecord) -> [TraceabilityLog] {
        (logsByRecord[record.id] ?? []).sorted { $0.timestamp > $1.timestamp }
    }

    /// Alimenti in ingresso collegati agli stessi piatti di questo lotto.
    func ingredientCount(for record: TraceabilityRecord) -> Int {
        let productionIds = productionIdsByRecord[record.id] ?? []
        guard !productionIds.isEmpty else { return 0 }
        var recordIds = Set<UUID>()
        for productionId in productionIds {
            if let linked = recordIdsByProduction[productionId] {
                recordIds.formUnion(linked)
            }
        }
        return recordIds.count
    }

    func ingredientCount(forProduction productionId: UUID) -> Int {
        recordIdsByProduction[productionId]?.count ?? 0
    }

    func productionArchiveGroups(
        records: [TraceabilityRecord],
        filter: TraceabilityHubFilter,
        searchText: String
    ) -> [TraceabilityProductionArchiveGroup] {
        let tokens = TraceabilityArchiveSearch.tokens(from: searchText)
        guard filter != .unlinked else { return [] }

        var buckets: [UUID: [TraceabilityRecord]] = [:]
        for record in records where record.isIncomingIngredientLot {
            for productionId in productionIdsByRecord[record.id] ?? [] {
                buckets[productionId, default: []].append(record)
            }
        }

        var groups = buckets.compactMap { productionId, bucketRecords -> TraceabilityProductionArchiveGroup? in
            guard let production = productionsById[productionId] else { return nil }
            let uniqueRecords = Dictionary(grouping: bucketRecords, by: \.id).compactMap(\.value.first)
            var ingredients = uniqueRecords
                .map { archiveIngredient(for: $0) }
            ingredients.append(contentsOf: trackedIngredients(forProductionId: productionId))
            ingredients.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            guard !ingredients.isEmpty else { return nil }

            let latestBatch = batches
                .filter { $0.productionId == productionId }
                .max(by: { $0.producedAt < $1.producedAt })

            let dishPhoto = latestBatch.flatMap { batch in
                ProductImageBytesResolver.productionDishPhoto(
                    batchId: batch.id,
                    images: allProductImages,
                    records: Array(recordsById.values)
                )
            }

            return TraceabilityProductionArchiveGroup(
                id: productionId.uuidString,
                productionId: productionId,
                productionName: production.name,
                batchId: latestBatch?.id,
                batchCode: latestBatch?.batchCode,
                registeredAt: latestBatch?.producedAt ?? ingredients.map(\.receivedAt).max() ?? Date(),
                ingredients: ingredients,
                photoData: dishPhoto
            )
        }

        groups = groups.filter { group in
            archiveGroupMatchesFilter(
                group,
                ingredientRecords: ingredientRecords(for: group, in: records),
                filter: filter
            )
        }

        if !tokens.isEmpty {
            groups = groups.filter { group in
                let production = productionsById[group.productionId]
                return TraceabilityArchiveSearch.groupMatchesSearch(
                    productionName: group.productionName,
                    categoryName: production?.categoryNameSnapshot,
                    ingredients: group.ingredients,
                    tokens: tokens,
                    batchCode: group.batchCode
                )
            }
        }

        return groups.sorted { lhs, rhs in
            if !tokens.isEmpty {
                let lProduction = productionsById[lhs.productionId]
                let rProduction = productionsById[rhs.productionId]
                let lScore = TraceabilityArchiveSearch.groupRelevanceScore(
                    productionName: lhs.productionName,
                    categoryName: lProduction?.categoryNameSnapshot,
                    ingredients: lhs.ingredients,
                    tokens: tokens
                )
                let rScore = TraceabilityArchiveSearch.groupRelevanceScore(
                    productionName: rhs.productionName,
                    categoryName: rProduction?.categoryNameSnapshot,
                    ingredients: rhs.ingredients,
                    tokens: tokens
                )
                if lScore != rScore { return lScore > rScore }
            }
            return lhs.registeredAt > rhs.registeredAt
        }
    }

    func unlinkedRecords(
        records: [TraceabilityRecord],
        filter: TraceabilityHubFilter,
        searchText: String
    ) -> [TraceabilityRecord] {
        filteredRecords(records, filter: filter, searchText: searchText)
            .filter {
                $0.isIncomingIngredientLot
                    && isActionable($0)
                    && (productionIdsByRecord[$0.id]?.isEmpty ?? true)
            }
            .sorted { $0.receivedAt > $1.receivedAt }
    }

    func criticalRecords(
        records: [TraceabilityRecord],
        filter: TraceabilityHubFilter,
        searchText: String
    ) -> [TraceabilityRecord] {
        filteredRecords(records, filter: filter, searchText: searchText)
            .filter { $0.isNonCompliant || $0.productStatus == .rejected }
            .sorted { $0.receivedAt > $1.receivedAt }
    }

    func image(forRecordId recordId: UUID) -> UIImage? {
        guard let record = recordsById[recordId] else { return nil }
        return image(for: record)
    }

    func lottoPhotoPath(for record: TraceabilityRecord) -> String? {
        if let lottoId = record.lottoFotoId, let lotto = lottoFotoById[lottoId] {
            if let path = existingPath(lotto.localPath) { return path }
            if let path = existingPath(lotto.thumbnailPath) { return path }
        }

        let recordImages = (imagesByRecord[record.id] ?? []).sorted { $0.createdAt > $1.createdAt }
        let preferred = recordImages.first { $0.type == .lotLabelOCR } ?? recordImages.first
        if let path = existingPath(preferred?.localPath) {
            return path
        }
        return nil
    }

    private func lottoImage(for record: TraceabilityRecord) -> UIImage? {
        if let lottoId = record.lottoFotoId, let lotto = lottoFotoById[lottoId] {
            return LottoFotoImageStorage.loadImage(at: lotto.localPath)
                ?? LottoFotoImageStorage.loadImage(at: lotto.thumbnailPath)
        }
        return nil
    }

    private func existingPath(_ path: String?) -> String? {
        guard let path, !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return nil }
        return path
    }

    // MARK: - Private

    private func isActionable(_ record: TraceabilityRecord) -> Bool {
        guard record.productStatus != .used, record.productStatus != .rejected else { return false }
        if record.productStatus == .expired { return false }
        if let expiry = record.expiryDate, ProductExpiryEvaluator.isExpiredByDate(expiry) {
            return false
        }
        return true
    }

    private func traceabilityStatus(
        for record: TraceabilityRecord,
        productionCount: Int,
        actionable: Bool
    ) -> (String, HACCPBadgeStyle) {
        if record.isNonCompliant { return ("Non conforme", .nonConforme) }
        if record.productStatus == .used { return ("Archiviato", .conforme) }
        if record.productStatus == .rejected { return ("Respinto", .nonConforme) }
        if actionable && productionCount == 0 && record.isIncomingIngredientLot {
            return ("Da associare", .info)
        }
        if productionCount > 0 { return ("Collegato", .conforme) }
        return ("Registrato", .info)
    }

    private func lotDisplay(for record: TraceabilityRecord) -> String {
        let lot = record.lotCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return lot.isEmpty ? "—" : lot
    }

    private func supplierDisplay(for record: TraceabilityRecord) -> String {
        let s = record.supplier.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? "—" : s
    }

    private func categoryDisplay(for record: TraceabilityRecord) -> String? {
        guard let raw = record.categoryRaw else { return nil }
        return GoodsCategory(rawValue: raw)?.rawValue ?? raw
    }

    private func matchesSearch(_ record: TraceabilityRecord, tokens: [String]) -> Bool {
        var fields = [
            record.productName,
            lotDisplay(for: record),
            supplierDisplay(for: record),
            record.productionReference ?? ""
        ]
        if let category = categoryDisplay(for: record) {
            fields.append(category)
        }
        for productionId in productionIdsByRecord[record.id] ?? [] {
            if let production = productionsById[productionId] {
                fields.append(production.name)
                fields.append(production.categoryNameSnapshot)
            }
        }
        return TraceabilityArchiveSearch.matchesAllTokens(tokens, in: fields)
    }

    private func ingredientRecords(
        for group: TraceabilityProductionArchiveGroup,
        in allRecords: [TraceabilityRecord]
    ) -> [TraceabilityRecord] {
        let ids = Set(group.ingredients.compactMap(\.recordId))
        return allRecords.filter { ids.contains($0.id) }
    }

    private func trackedIngredients(
        forProductionId productionId: UUID
    ) -> [TraceabilityArchiveIngredientItem] {
        let productionBatchIds = Set(batches.filter { $0.productionId == productionId }.map(\.id))
        return ingredientiTracciati
            .filter { productionBatchIds.contains($0.produzioneBatchId) }
            .compactMap { tracked -> TraceabilityArchiveIngredientItem? in
                let lot = tracked.lotCodeExtracted?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !lot.isEmpty else { return nil }
                let name = tracked.ingredientNameAssigned
                    ?? tracked.ingredientNameHint
                    ?? "Alimento"
                return TraceabilityArchiveIngredientItem(
                    id: tracked.id,
                    recordId: nil,
                    name: name,
                    lotCode: lot,
                    supplier: "Produzione",
                    receivedAt: tracked.lotRegisteredAt ?? tracked.createdAt
                )
            }
    }

    private func archiveGroupMatchesFilter(
        _ group: TraceabilityProductionArchiveGroup,
        ingredientRecords: [TraceabilityRecord],
        filter: TraceabilityHubFilter
    ) -> Bool {
        switch filter {
        case .all:
            return true
        case .unlinked:
            return false
        case .today:
            if Calendar.current.isDateInToday(group.registeredAt) { return true }
            if group.ingredients.contains(where: { Calendar.current.isDateInToday($0.receivedAt) }) { return true }
            return ingredientRecords.contains { Calendar.current.isDateInToday($0.createdAt) }
        case .critical:
            return ingredientRecords.contains { $0.isNonCompliant || $0.productStatus == .rejected }
        }
    }

    private func archiveIngredient(for record: TraceabilityRecord) -> TraceabilityArchiveIngredientItem {
        let photos = ProductImageBytesResolver.allPhotos(
            record: record,
            images: imagesForPhotoLookup(record),
            lottoFotos: Array(lottoFotoById.values)
        )
        return TraceabilityArchiveIngredientItem(
            id: record.id,
            recordId: record.id,
            name: record.productName,
            lotCode: lotDisplay(for: record),
            supplier: supplierDisplay(for: record),
            receivedAt: record.receivedAt,
            photoData: photos.first
        )
    }

}
