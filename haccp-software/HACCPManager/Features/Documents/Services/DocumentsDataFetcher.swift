//
//  DocumentsDataFetcher.swift
//  Fetch mirati per archivio PDF — evita @Query globali in DocumentsView.
//

import Foundation
import SwiftData

struct DocumentsArchiveFetchedData {
    var folders: [DocumentFolder] = []
    var items: [DocumentItem] = []
}

struct DocumentsCSVExportSources {
    var receipts: [GoodsReceipt] = []
    var traceability: [TraceabilityRecord] = []
    var images: [ProductImage] = []
    var productions: [Production] = []
    var links: [TraceabilityLink] = []
    var logs: [TraceabilityLog] = []
}

enum DocumentsDataFetcher {

    static func fetchArchive(context: ModelContext, restaurantId: UUID) -> DocumentsArchiveFetchedData {
        let rid = restaurantId
        var data = DocumentsArchiveFetchedData()

        var folderDescriptor = FetchDescriptor<DocumentFolder>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\DocumentFolder.orderIndex), SortDescriptor(\DocumentFolder.name)]
        )
        folderDescriptor.fetchLimit = PerformanceConfig.documentsFolderFetchLimit
        data.folders = (try? context.fetch(folderDescriptor)) ?? []

        var itemDescriptor = FetchDescriptor<DocumentItem>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\DocumentItem.generatedAt, order: .reverse)]
        )
        itemDescriptor.fetchLimit = PerformanceConfig.documentsItemFetchLimit
        data.items = (try? context.fetch(itemDescriptor)) ?? []

        return data
    }

    /// Carica solo i dati operativi necessari per l'export CSV di un singolo registro.
    static func fetchCSVExportSources(
        context: ModelContext,
        restaurantId: UUID,
        document: DocumentItem,
        calendar: Calendar = {
            var cal = Calendar(identifier: .gregorian)
            cal.locale = Locale(identifier: "it_IT")
            cal.timeZone = .current
            return cal
        }()
    ) -> DocumentsCSVExportSources {
        guard let interval = reportingInterval(for: document, calendar: calendar) else {
            return DocumentsCSVExportSources()
        }
        return fetchCSVExportSources(
            context: context,
            restaurantId: restaurantId,
            interval: interval
        )
    }

    static func fetchCSVExportSources(
        context: ModelContext,
        restaurantId: UUID,
        interval: DateInterval
    ) -> DocumentsCSVExportSources {
        let rid = restaurantId
        let start = interval.start
        let end = interval.end
        let limit = PerformanceConfig.documentsCSVExportFetchLimit
        var sources = DocumentsCSVExportSources()

        var receiptDescriptor = FetchDescriptor<GoodsReceivingRecord>(
            predicate: #Predicate {
                $0.restaurantId == rid && $0.receivedAt >= start && $0.receivedAt < end
            },
            sortBy: [SortDescriptor(\GoodsReceivingRecord.receivedAt, order: .reverse)]
        )
        receiptDescriptor.fetchLimit = limit
        sources.receipts = (try? context.fetch(receiptDescriptor)) ?? []

        var traceDescriptor = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate {
                $0.restaurantId == rid && $0.receivedAt >= start && $0.receivedAt < end
            },
            sortBy: [SortDescriptor(\TraceabilityRecord.receivedAt, order: .reverse)]
        )
        traceDescriptor.fetchLimit = limit
        sources.traceability = (try? context.fetch(traceDescriptor)) ?? []

        var productionDescriptor = FetchDescriptor<Production>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\Production.name)]
        )
        productionDescriptor.fetchLimit = 300
        sources.productions = (try? context.fetch(productionDescriptor)) ?? []

        let recordIds = Set(sources.traceability.map(\.id))
        guard !recordIds.isEmpty else { return sources }

        var linkDescriptor = FetchDescriptor<TraceabilityLink>()
        linkDescriptor.fetchLimit = limit * 2
        sources.links = ((try? context.fetch(linkDescriptor)) ?? [])
            .filter { recordIds.contains($0.receivedItemId) }

        var logDescriptor = FetchDescriptor<TraceabilityLog>(
            sortBy: [SortDescriptor(\TraceabilityLog.timestamp, order: .reverse)]
        )
        logDescriptor.fetchLimit = limit * 2
        sources.logs = ((try? context.fetch(logDescriptor)) ?? [])
            .filter { recordIds.contains($0.receivedItemId) }

        var imageDescriptor = FetchDescriptor<ProductImage>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\ProductImage.createdAt, order: .reverse)]
        )
        imageDescriptor.fetchLimit = limit * 2
        sources.images = ((try? context.fetch(imageDescriptor)) ?? [])
            .filter { image in
                if let batchId = image.produzioneBatchId { return true }
                if let rid = image.receivedItemId { return recordIds.contains(rid) }
                return false
            }

        return sources
    }

    private static func reportingInterval(for item: DocumentItem, calendar: Calendar) -> DateInterval? {
        guard let periodStart = item.periodStart else { return nil }
        let effectiveType: DocumentType = (item.type == .mensile && item.module == .nonConformita)
            ? .nonConformita
            : item.type
        switch effectiveType {
        case .giornaliero:
            let day = calendar.startOfDay(for: periodStart)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
            return DateInterval(start: day, end: dayEnd)
        case .mensile, .nonConformita:
            return calendar.dateInterval(of: .month, for: periodStart)
        case .annuale:
            return calendar.dateInterval(of: .year, for: periodStart)
        default:
            let day = calendar.startOfDay(for: periodStart)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
            return DateInterval(start: day, end: dayEnd)
        }
    }
}
