//
//  DataArchiveService.swift
//  Archivia record oltre la retention, comprime foto, alleggerisce query operative.
//

import Foundation
import SwiftData

enum DataArchiveService {

    private static func lastRunKey(restaurantId: UUID) -> String {
        "DataArchiveService.lastRun.\(restaurantId.uuidString)"
    }

    /// Esegue al massimo un ciclo al giorno per ristorante (orchestrazione UI — lavoro pesante off-main).
    @MainActor
    static func runIfNeeded(modelContainer: ModelContainer, restaurantId: UUID) async {
        let key = lastRunKey(restaurantId: restaurantId)
        if let last = UserDefaults.standard.object(forKey: key) as? Date,
           Date().timeIntervalSince(last) < PerformanceConfig.archiveRunInterval {
            return
        }

        let actor = BackgroundPersistenceActor(modelContainer: modelContainer)
        let archivedCount = await actor.archiveRestaurant(restaurantId: restaurantId)
        if archivedCount > 0 {
            _ = await actor.saveAfterArchive()
        }
        UserDefaults.standard.set(Date(), forKey: key)
    }

    /// Versione legacy con context main — preferire `runIfNeeded(modelContainer:)`.
    @MainActor
    static func runIfNeeded(context: ModelContext, restaurantId: UUID) async {
        await runIfNeeded(modelContainer: context.container, restaurantId: restaurantId)
    }

    @discardableResult
    static func archiveRestaurant(context: ModelContext, restaurantId: UUID) -> Int {
        let cutoff = Calendar.current.date(
            byAdding: .month,
            value: -PerformanceConfig.activeDataRetentionMonths,
            to: Date()
        ) ?? Date.distantPast
        let batch = PerformanceConfig.archiveBatchSize
        var total = 0

        total += archiveTemperature(context, restaurantId: restaurantId, cutoff: cutoff, batch: batch)
        total += archiveChecklistRuns(context, restaurantId: restaurantId, cutoff: cutoff, batch: batch)
        total += archiveTraceability(context, restaurantId: restaurantId, cutoff: cutoff, batch: batch)
        total += archiveCleaning(context, restaurantId: restaurantId, cutoff: cutoff, batch: batch)
        total += archiveBlast(context, restaurantId: restaurantId, cutoff: cutoff, batch: batch)
        total += archiveDefrost(context, restaurantId: restaurantId, cutoff: cutoff, batch: batch)
        total += archiveOil(context, restaurantId: restaurantId, cutoff: cutoff, batch: batch)
        total += archiveGoods(context, restaurantId: restaurantId, cutoff: cutoff, batch: batch)
        total += archiveFridge(context, restaurantId: restaurantId, cutoff: cutoff, batch: batch)
        total += archiveLabels(context, restaurantId: restaurantId, cutoff: cutoff, batch: batch)

        return total
    }

    // MARK: - Per tipo

    private static func archiveTemperature(
        _ context: ModelContext,
        restaurantId: UUID,
        cutoff: Date,
        batch: Int
    ) -> Int {
        let rid = restaurantId
        var descriptor = FetchDescriptor<TemperatureRecord>(
            predicate: #Predicate {
                $0.restaurantId == rid && !$0.isArchived && $0.measuredAt < cutoff
            },
            sortBy: [SortDescriptor(\TemperatureRecord.measuredAt)]
        )
        descriptor.fetchLimit = batch
        let batch = (try? context.fetch(descriptor)) ?? []
        let now = Date()
        for record in batch {
            record.isArchived = true
            record.archivedAt = now
        }
        return batch.count
    }

    private static func archiveChecklistRuns(
        _ context: ModelContext,
        restaurantId: UUID,
        cutoff: Date,
        batch: Int
    ) -> Int {
        let rid = restaurantId
        var descriptor = FetchDescriptor<ChecklistRun>(
            predicate: #Predicate {
                $0.restaurantId == rid && !$0.isArchived && $0.startedAt < cutoff
            },
            sortBy: [SortDescriptor(\ChecklistRun.startedAt)]
        )
        descriptor.fetchLimit = batch
        let batch = (try? context.fetch(descriptor)) ?? []
        let now = Date()
        for record in batch {
            record.isArchived = true
            record.archivedAt = now
        }
        return batch.count
    }

    private static func archiveTraceability(
        _ context: ModelContext,
        restaurantId: UUID,
        cutoff: Date,
        batch: Int
    ) -> Int {
        let rid = restaurantId
        var descriptor = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate {
                $0.restaurantId == rid && !$0.isArchived && $0.receivedAt < cutoff
            },
            sortBy: [SortDescriptor(\TraceabilityRecord.receivedAt)]
        )
        descriptor.fetchLimit = batch
        let records = (try? context.fetch(descriptor)) ?? []
        var count = 0
        let now = Date()
        for record in records where !record.isNonCompliant || record.nonComplianceResolvedAt != nil {
            compressTraceabilityPhotos(record, context: context)
            record.isArchived = true
            record.archivedAt = now
            count += 1
        }
        return count
    }

    private static func archiveCleaning(
        _ context: ModelContext,
        restaurantId: UUID,
        cutoff: Date,
        batch: Int
    ) -> Int {
        let rid = restaurantId
        var descriptor = FetchDescriptor<CleaningRecord>(
            predicate: #Predicate {
                $0.restaurantId == rid && !$0.isArchived && $0.periodEnd < cutoff
            },
            sortBy: [SortDescriptor(\CleaningRecord.periodEnd)]
        )
        descriptor.fetchLimit = batch
        let batch = (try? context.fetch(descriptor)) ?? []
        let now = Date()
        for record in batch {
            record.isArchived = true
            record.archivedAt = now
        }
        return batch.count
    }

    private static func archiveBlast(
        _ context: ModelContext,
        restaurantId: UUID,
        cutoff: Date,
        batch: Int
    ) -> Int {
        let rid = restaurantId
        var descriptor = FetchDescriptor<BlastChillingRecord>(
            predicate: #Predicate {
                $0.restaurantId == rid && !$0.isArchived && $0.startedAt < cutoff
            },
            sortBy: [SortDescriptor(\BlastChillingRecord.startedAt)]
        )
        descriptor.fetchLimit = batch
        let batch = (try? context.fetch(descriptor)) ?? []
        let now = Date()
        for record in batch {
            record.isArchived = true
            record.archivedAt = now
        }
        return batch.count
    }

    private static func archiveDefrost(
        _ context: ModelContext,
        restaurantId: UUID,
        cutoff: Date,
        batch: Int
    ) -> Int {
        let rid = restaurantId
        var descriptor = FetchDescriptor<DefrostRecord>(
            predicate: #Predicate {
                $0.restaurantId == rid && !$0.isArchived && $0.endAt != nil && $0.startAt < cutoff
            },
            sortBy: [SortDescriptor(\DefrostRecord.startAt)]
        )
        descriptor.fetchLimit = batch
        let batch = (try? context.fetch(descriptor)) ?? []
        let now = Date()
        for record in batch {
            record.isArchived = true
            record.archivedAt = now
        }
        return batch.count
    }

    private static func archiveOil(
        _ context: ModelContext,
        restaurantId: UUID,
        cutoff: Date,
        batch: Int
    ) -> Int {
        let rid = restaurantId
        var descriptor = FetchDescriptor<OilControlRecord>(
            predicate: #Predicate {
                $0.restaurantId == rid && !$0.isArchived && $0.checkedAt < cutoff
            },
            sortBy: [SortDescriptor(\OilControlRecord.checkedAt)]
        )
        descriptor.fetchLimit = batch
        let records = (try? context.fetch(descriptor)) ?? []
        var count = 0
        let now = Date()
        for record in records {
            if let data = record.nonCompliancePhotoData {
                record.nonCompliancePhotoData = StoredImageCompression.preparedForArchive(data)
            }
            record.isArchived = true
            record.archivedAt = now
            count += 1
        }
        return count
    }

    private static func archiveGoods(
        _ context: ModelContext,
        restaurantId: UUID,
        cutoff: Date,
        batch: Int
    ) -> Int {
        let rid = restaurantId
        var descriptor = FetchDescriptor<GoodsReceivingRecord>(
            predicate: #Predicate {
                $0.restaurantId == rid && !$0.isArchived && $0.receivedAt < cutoff
            },
            sortBy: [SortDescriptor(\GoodsReceivingRecord.receivedAt)]
        )
        descriptor.fetchLimit = batch
        let receipts = (try? context.fetch(descriptor)) ?? []
        var count = 0
        let now = Date()
        for receipt in receipts {
            if let data = receipt.photoData {
                receipt.photoData = StoredImageCompression.preparedForArchive(data)
            }
            receipt.isArchived = true
            receipt.archivedAt = now
            count += 1
        }
        return count
    }

    private static func archiveFridge(
        _ context: ModelContext,
        restaurantId: UUID,
        cutoff: Date,
        batch: Int
    ) -> Int {
        let rid = restaurantId
        var descriptor = FetchDescriptor<FridgeCheckRecord>(
            predicate: #Predicate {
                $0.restaurantId == rid && !$0.isArchived && $0.createdAt < cutoff
            },
            sortBy: [SortDescriptor(\FridgeCheckRecord.createdAt)]
        )
        descriptor.fetchLimit = batch
        let batch = (try? context.fetch(descriptor)) ?? []
        let now = Date()
        for record in batch {
            record.isArchived = true
            record.archivedAt = now
        }
        return batch.count
    }

    private static func archiveLabels(
        _ context: ModelContext,
        restaurantId: UUID,
        cutoff: Date,
        batch: Int
    ) -> Int {
        let rid = restaurantId
        var descriptor = FetchDescriptor<ProductionLabelRecord>(
            predicate: #Predicate {
                $0.restaurantId == rid && !$0.isArchived && $0.createdAt < cutoff
            },
            sortBy: [SortDescriptor(\ProductionLabelRecord.createdAt)]
        )
        descriptor.fetchLimit = batch
        let batch = (try? context.fetch(descriptor)) ?? []
        let now = Date()
        for record in batch {
            record.isArchived = true
            record.archivedAt = now
        }
        return batch.count
    }

    // MARK: - Helpers

    private static func compressTraceabilityPhotos(_ record: TraceabilityRecord, context: ModelContext) {
        if let data = record.photoData {
            record.photoData = StoredImageCompression.preparedForArchive(data)
        }
        var descriptor = FetchDescriptor<ProductImage>(
            sortBy: [SortDescriptor(\ProductImage.createdAt)]
        )
        descriptor.fetchLimit = 32
        let images = (try? context.fetch(descriptor)) ?? []
        for image in images where image.receivedItemId == record.id {
            if let data = image.imageData {
                image.imageData = StoredImageCompression.preparedForArchive(data)
            }
            image.isArchived = true
            image.archivedAt = Date()
        }
    }
}
