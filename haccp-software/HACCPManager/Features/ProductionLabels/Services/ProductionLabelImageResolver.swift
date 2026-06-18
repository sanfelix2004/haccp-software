//
//  ProductionLabelImageResolver.swift
//  Foto prodotto da tracciabilità / ricezione collegata all'etichetta.
//

import Foundation
import SwiftData

enum ProductionLabelImageResolver {

    static func imageData(for label: ProductionLabelRecord, context: ModelContext) -> Data? {
        if let traceId = label.traceabilityRecordId,
           let data = traceabilityImageData(traceId: traceId, context: context) {
            return data
        }
        if let goodsId = label.goodsReceiptId,
           let data = goodsReceiptImageData(receiptId: goodsId, context: context) {
            return data
        }
        if let defrostId = label.defrostRecordId,
           let traceId = defrostTraceabilityId(defrostId: defrostId, context: context),
           let data = traceabilityImageData(traceId: traceId, context: context) {
            return data
        }
        return nil
    }

    private static func traceabilityImageData(traceId: UUID, context: ModelContext) -> Data? {
        guard let record = fetchTraceability(traceId: traceId, context: context) else { return nil }

        if let images = productImages(for: record.id, context: context) {
            for image in images {
                if let bytes = image.imageData, !bytes.isEmpty { return bytes }
                if let path = image.localPath,
                   let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                   !data.isEmpty {
                    return data
                }
            }
        }

        if let data = record.photoData, !data.isEmpty { return data }

        if let goodsId = record.goodsReceiptId,
           let data = goodsReceiptImageData(receiptId: goodsId, context: context) {
            return data
        }

        return nil
    }

    private static func goodsReceiptImageData(receiptId: UUID, context: ModelContext) -> Data? {
        var descriptor = FetchDescriptor<GoodsReceivingRecord>(
            predicate: #Predicate { $0.id == receiptId }
        )
        descriptor.fetchLimit = 1
        guard let receipt = try? context.fetch(descriptor).first,
              let data = receipt.photoData,
              !data.isEmpty else {
            return nil
        }
        return data
    }

    private static func defrostTraceabilityId(defrostId: UUID, context: ModelContext) -> UUID? {
        var descriptor = FetchDescriptor<DefrostRecord>(
            predicate: #Predicate { $0.id == defrostId }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.traceabilityItemId
    }

    private static func fetchTraceability(traceId: UUID, context: ModelContext) -> TraceabilityRecord? {
        var descriptor = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate { $0.id == traceId }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func productImages(for receivedItemId: UUID, context: ModelContext) -> [ProductImage]? {
        var descriptor = FetchDescriptor<ProductImage>(
            predicate: #Predicate { $0.receivedItemId == receivedItemId },
            sortBy: [SortDescriptor(\ProductImage.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 8
        return try? context.fetch(descriptor)
    }
}
