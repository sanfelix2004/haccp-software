//
//  HistoryDataFetcher.swift
//  Fetch mirati con limite — evita caricare l'intero database in RAM.
//

import Foundation
import SwiftData

struct HistoryFetchedData {
    var temperatureRecords: [TemperatureRecord] = []
    var fridgeRecords: [FridgeCheckRecord] = []
    var checklistRuns: [ChecklistRun] = []
    var checklistItemResults: [ChecklistItemResult] = []
    var cleaningRecords: [CleaningRecord] = []
    var defrostRecords: [DefrostRecord] = []
    var blastRecords: [BlastChillingRecord] = []
    var labelRecords: [ProductionLabelRecord] = []
    var goodsRecords: [GoodsReceipt] = []
    var traceabilityRecords: [TraceabilityRecord] = []
    var traceabilityLinks: [TraceabilityLink] = []
    var traceabilityLogs: [TraceabilityLog] = []
    var lottoProductionLinks: [LottoFotoProductionLink] = []
    var lottoFotos: [LottoFoto] = []
    var productions: [Production] = []
    var produzioneBatches: [ProduzioneBatch] = []
    var productImages: [ProductImage] = []
    var oilRecords: [OilControlRecord] = []
}

enum HistoryDataFetcher {

    static func fetch(context: ModelContext, restaurantId: UUID) -> HistoryFetchedData {
        let limit = PerformanceConfig.historyFetchLimitPerType
        let rid = restaurantId

        var data = HistoryFetchedData()
        data.temperatureRecords = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\TemperatureRecord.measuredAt, order: .reverse))
        data.fridgeRecords = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\FridgeCheckRecord.createdAt, order: .reverse))
        data.checklistRuns = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\ChecklistRun.startedAt, order: .reverse))
        data.checklistItemResults = fetchChecklistItemResults(context, runIds: Set(data.checklistRuns.map(\.id)), limit: limit * 2)
        data.cleaningRecords = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\CleaningRecord.createdAt, order: .reverse))
        data.defrostRecords = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\DefrostRecord.startAt, order: .reverse))
        data.blastRecords = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\BlastChillingRecord.startedAt, order: .reverse))
        data.labelRecords = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\ProductionLabelRecord.createdAt, order: .reverse))
        data.goodsRecords = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\GoodsReceipt.receivedAt, order: .reverse))
        data.traceabilityRecords = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\TraceabilityRecord.createdAt, order: .reverse))
        let recordIds = Set(data.traceabilityRecords.map(\.id))
        data.traceabilityLinks = fetchTraceabilityLinks(
            context,
            recordIds: recordIds,
            limit: limit * 3
        )
        data.traceabilityLogs = fetchTraceabilityLogs(
            context,
            recordIds: recordIds,
            limit: limit * 4
        )
        data.lottoFotos = fetchLottoFotos(context, restaurantId: rid, limit: limit * 2)
        data.lottoProductionLinks = fetchLottoProductionLinks(
            context,
            lottoIds: Set(data.lottoFotos.map(\.id)),
            limit: limit * 3
        )
        data.productions = fetchLimited(context, restaurantId: rid, limit: 500, sort: SortDescriptor(\Production.name, order: .forward))
        data.produzioneBatches = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\ProduzioneBatch.producedAt, order: .reverse))
        data.productImages = fetchProductImages(context, restaurantId: rid, limit: limit * 3)
        data.oilRecords = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\OilControlRecord.checkedAt, order: .reverse))
        return data
    }

    private static func fetchLimited<T: PersistentModel>(
        _ context: ModelContext,
        restaurantId: UUID,
        limit: Int,
        sort: SortDescriptor<T>
    ) -> [T] where T: RestaurantScoped {
        var descriptor = FetchDescriptor<T>(
            predicate: #Predicate { $0.restaurantId == restaurantId },
            sortBy: [sort]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func fetchTraceabilityLogs(
        _ context: ModelContext,
        recordIds: Set<UUID>,
        limit: Int
    ) -> [TraceabilityLog] {
        guard !recordIds.isEmpty else { return [] }
        var descriptor = FetchDescriptor<TraceabilityLog>(
            sortBy: [SortDescriptor(\TraceabilityLog.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return ((try? context.fetch(descriptor)) ?? []).filter { recordIds.contains($0.receivedItemId) }
    }

    private static func fetchTraceabilityLinks(
        _ context: ModelContext,
        recordIds: Set<UUID>,
        limit: Int
    ) -> [TraceabilityLink] {
        guard !recordIds.isEmpty else { return [] }
        var descriptor = FetchDescriptor<TraceabilityLink>(
            sortBy: [SortDescriptor(\TraceabilityLink.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return ((try? context.fetch(descriptor)) ?? []).filter { recordIds.contains($0.receivedItemId) }
    }

    private static func fetchLottoProductionLinks(
        _ context: ModelContext,
        lottoIds: Set<UUID>,
        limit: Int
    ) -> [LottoFotoProductionLink] {
        guard !lottoIds.isEmpty else { return [] }
        var descriptor = FetchDescriptor<LottoFotoProductionLink>(
            sortBy: [SortDescriptor(\LottoFotoProductionLink.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return ((try? context.fetch(descriptor)) ?? []).filter { lottoIds.contains($0.lottoFotoId) }
    }

    private static func fetchLottoFotos(
        _ context: ModelContext,
        restaurantId: UUID,
        limit: Int
    ) -> [LottoFoto] {
        let rid = restaurantId
        var descriptor = FetchDescriptor<LottoFoto>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\LottoFoto.dataScatto, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func fetchChecklistItemResults(
        _ context: ModelContext,
        runIds: Set<UUID>,
        limit: Int
    ) -> [ChecklistItemResult] {
        guard !runIds.isEmpty else { return [] }
        var descriptor = FetchDescriptor<ChecklistItemResult>(
            sortBy: [SortDescriptor(\ChecklistItemResult.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let batch = (try? context.fetch(descriptor)) ?? []
        return batch.filter { runIds.contains($0.checklistRunId) }
    }

    private static func fetchProductImages(
        _ context: ModelContext,
        restaurantId: UUID,
        limit: Int
    ) -> [ProductImage] {
        _ = restaurantId
        var descriptor = FetchDescriptor<ProductImage>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\ProductImage.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }
}

/// Modelli con `restaurantId` per fetch mirati.
protocol RestaurantScoped {
    var restaurantId: UUID { get }
}

extension TemperatureRecord: RestaurantScoped {}
extension FridgeCheckRecord: RestaurantScoped {}
extension ChecklistRun: RestaurantScoped {}
extension ChecklistAuditLog: RestaurantScoped {}
extension CleaningRecord: RestaurantScoped {}
extension DefrostRecord: RestaurantScoped {}
extension BlastChillingRecord: RestaurantScoped {}
extension ProductionLabelRecord: RestaurantScoped {}
extension Production: RestaurantScoped {}
extension ProduzioneBatch: RestaurantScoped {}
extension GoodsReceipt: RestaurantScoped {}
extension TraceabilityRecord: RestaurantScoped {}
extension ScheduledTask: RestaurantScoped {}
extension OilControlRecord: RestaurantScoped {}
extension DocumentFolder: RestaurantScoped {}
