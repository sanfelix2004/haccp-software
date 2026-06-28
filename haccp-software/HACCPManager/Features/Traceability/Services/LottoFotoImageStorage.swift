import Foundation
import UIKit
import SwiftData

/// Salvataggio immagini lotto su disco (Documents), non come blob in DB.
enum LottoFotoImageStorage {

    private static let folderName = "lotto-foto"

    struct StoredPaths: Sendable {
        let originalPath: String
        let thumbnailPath: String?
    }

    static func save(
        photoData: Data,
        restaurantId: UUID,
        lottoFotoId: UUID
    ) throws -> StoredPaths {
        guard !photoData.isEmpty else {
            throw NSError(
                domain: "LottoFotoImageStorage",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Immagine vuota: impossibile salvare la foto."]
            )
        }

        let directory = try ensureDirectory(restaurantId: restaurantId)
        let baseName = lottoFotoId.uuidString

        let compressed = StoredImageCompression.preparedForStorage(photoData) ?? photoData
        guard !compressed.isEmpty else {
            throw NSError(
                domain: "LottoFotoImageStorage",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Compressione foto non riuscita."]
            )
        }

        let originalURL = directory.appendingPathComponent("\(baseName).jpg")
        try compressed.write(to: originalURL, options: .atomic)
        guard FileManager.default.fileExists(atPath: originalURL.path),
              FileManager.default.isReadableFile(atPath: originalURL.path) else {
            throw NSError(
                domain: "LottoFotoImageStorage",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "File foto non scritto correttamente su disco."]
            )
        }

        let thumbnailURL = directory.appendingPathComponent("\(baseName)_thumb.jpg")
        let thumbnailPath: String?
        if let thumbData = StoredImageCompression.preparedForArchive(compressed), !thumbData.isEmpty {
            try thumbData.write(to: thumbnailURL, options: .atomic)
            thumbnailPath = FileManager.default.fileExists(atPath: thumbnailURL.path)
                ? thumbnailURL.path
                : nil
        } else {
            thumbnailPath = nil
        }

        return StoredPaths(originalPath: originalURL.path, thumbnailPath: thumbnailPath)
    }

    /// Carica immagine da percorso disco; opzionalmente da `ProductImage` collegata al lotto.
    static func loadImage(
        for lotto: LottoFoto,
        modelContext: ModelContext
    ) -> UIImage? {
        if let image = loadImage(at: lotto.thumbnailPath) ?? loadImage(at: lotto.localPath) {
            return image
        }
        return inlineImage(for: lotto, modelContext: modelContext)
    }

    private static func inlineImage(for lotto: LottoFoto, modelContext: ModelContext) -> UIImage? {
        let lottoId = lotto.id
        let records = (try? modelContext.fetch(FetchDescriptor<TraceabilityRecord>())) ?? []
        guard let recordId = records.first(where: { $0.lottoFotoId == lottoId })?.id else { return nil }

        let images = (try? modelContext.fetch(FetchDescriptor<ProductImage>())) ?? []
        let recordImages = images
            .filter { $0.receivedItemId == recordId && !$0.isArchived }
            .sorted { $0.createdAt > $1.createdAt }
        for image in recordImages.prefix(4) {
            if let bytes = image.imageData, !bytes.isEmpty, let uiImage = UIImage(data: bytes) {
                return uiImage
            }
            if let image = loadImage(at: image.localPath) {
                return image
            }
        }
        return nil
    }

    static func loadImage(at path: String?) -> UIImage? {
        guard let path, !path.isEmpty else { return nil }
        return UIImage(contentsOfFile: path)
    }

    static func deleteFiles(originalPath: String, thumbnailPath: String?) {
        try? FileManager.default.removeItem(atPath: originalPath)
        if let thumbnailPath, !thumbnailPath.isEmpty {
            try? FileManager.default.removeItem(atPath: thumbnailPath)
        }
    }

    private static func ensureDirectory(restaurantId: UUID) throws -> URL {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(
                domain: "LottoFotoImageStorage",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Cartella Documents non disponibile."]
            )
        }
        let directory = documents
            .appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent(restaurantId.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
