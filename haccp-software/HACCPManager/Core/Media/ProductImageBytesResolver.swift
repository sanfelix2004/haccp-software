import Foundation
import UIKit

/// Risolve i byte foto da ProductImage / disco / campi inline (storico + documenti).
enum ProductImageBytesResolver {

    static func bytes(from image: ProductImage) -> Data? {
        if let data = image.imageData, !data.isEmpty { return data }
        if let path = image.localPath,
           let ui = LottoFotoImageStorage.loadImage(at: path),
           let jpeg = ui.jpegData(compressionQuality: 0.85),
           !jpeg.isEmpty {
            return jpeg
        }
        return nil
    }

    static func resolve(
        record: TraceabilityRecord,
        images: [ProductImage],
        lottoFotos: [LottoFoto] = []
    ) -> Data? {
        if let data = record.photoData, !data.isEmpty { return data }

        var linked = images
            .filter { !$0.isArchived && $0.receivedItemId == record.id }
        if let goodsId = record.goodsReceiptId {
            linked += images.filter { !$0.isArchived && $0.goodsReceiptId == goodsId }
        }
        linked = linked.sorted { lhs, rhs in
            preferredRank(lhs.type) < preferredRank(rhs.type)
                || (preferredRank(lhs.type) == preferredRank(rhs.type) && lhs.createdAt > rhs.createdAt)
        }
        var seen = Set<UUID>()
        for image in linked where seen.insert(image.id).inserted {
            if let data = bytes(from: image) { return data }
        }

        if let lottoId = record.lottoFotoId,
           let lotto = lottoFotos.first(where: { $0.id == lottoId }) {
            if let ui = LottoFotoImageStorage.loadImage(at: lotto.localPath)
                ?? LottoFotoImageStorage.loadImage(at: lotto.thumbnailPath),
               let jpeg = ui.jpegData(compressionQuality: 0.85),
               !jpeg.isEmpty {
                return jpeg
            }
        }
        return nil
    }

    /// Foto del piatto finito per un batch: solo `.productionDish`, mai etichette ingredienti.
    static func productionDishPhoto(
        batchId: UUID,
        images: [ProductImage],
        records: [TraceabilityRecord] = []
    ) -> Data? {
        let fromImages = images
            .filter {
                !$0.isArchived
                    && $0.produzioneBatchId == batchId
                    && $0.type == .productionDish
            }
            .sorted { $0.createdAt > $1.createdAt }
            .compactMap { bytes(from: $0) }
            .first
        if let fromImages { return fromImages }

        return records
            .first { record in
                record.produzioneBatchId == batchId
                    && !record.isArchived
                    && record.isProductionBatchOutput
            }
            .flatMap { $0.photoData.flatMap { $0.isEmpty ? nil : $0 } }
    }

    /// Tutte le foto utili per un lotto (NC multiple, etichette, ecc.).
    static func allPhotos(
        record: TraceabilityRecord,
        images: [ProductImage],
        lottoFotos: [LottoFoto] = []
    ) -> [Data] {
        var result: [Data] = []
        var seen = Set<Int>()

        func append(_ data: Data?) {
            guard let data, !data.isEmpty else { return }
            let key = data.hashValue
            guard !seen.contains(key) else { return }
            seen.insert(key)
            result.append(data)
        }

        append(record.photoData)
        var linked = images.filter { !$0.isArchived && $0.receivedItemId == record.id }
        if let goodsId = record.goodsReceiptId {
            linked += images.filter { !$0.isArchived && $0.goodsReceiptId == goodsId }
        }
        var seenIds = Set<UUID>()
        for image in linked.sorted(by: { $0.createdAt < $1.createdAt }) where seenIds.insert(image.id).inserted {
            append(bytes(from: image))
        }
        if let lottoId = record.lottoFotoId,
           let lotto = lottoFotos.first(where: { $0.id == lottoId }) {
            if let ui = LottoFotoImageStorage.loadImage(at: lotto.localPath)
                ?? LottoFotoImageStorage.loadImage(at: lotto.thumbnailPath) {
                append(ui.jpegData(compressionQuality: 0.85))
            }
        }
        return result
    }

    /// Foto ricezione (NC o documentazione).
    static func resolve(
        receipt: GoodsReceipt,
        images: [ProductImage]
    ) -> Data? {
        if let data = receipt.photoData, !data.isEmpty { return data }
        let linked = images
            .filter { !$0.isArchived && $0.goodsReceiptId == receipt.id }
            .sorted { $0.createdAt < $1.createdAt }
        for image in linked {
            if let data = bytes(from: image) { return data }
        }
        // Legacy: ProductImage con receivedItemId = receipt.id
        let legacy = images
            .filter { !$0.isArchived && $0.receivedItemId == receipt.id }
            .sorted { $0.createdAt < $1.createdAt }
        for image in legacy {
            if let data = bytes(from: image) { return data }
        }
        return nil
    }

    static func allPhotos(
        receipt: GoodsReceipt,
        images: [ProductImage]
    ) -> [Data] {
        var result: [Data] = []
        var seen = Set<Int>()

        func append(_ data: Data?) {
            guard let data, !data.isEmpty else { return }
            let key = data.hashValue
            guard !seen.contains(key) else { return }
            seen.insert(key)
            result.append(data)
        }

        append(receipt.photoData)
        let linked = images.filter {
            !$0.isArchived && ($0.goodsReceiptId == receipt.id || $0.receivedItemId == receipt.id)
        }
        .sorted { $0.createdAt < $1.createdAt }
        for image in linked {
            append(bytes(from: image))
        }
        return result
    }

    private static func preferredRank(_ type: ProductImageType) -> Int {
        switch type {
        case .productionDish: return 0
        case .nonComplianceRequired, .nonCompliance: return 1
        case .lotLabelOCR: return 2
        case .receiptOptional, .generic: return 3
        }
    }
}
