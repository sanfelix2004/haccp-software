import Foundation
import SwiftData

/// Regole condivise per hub tracciabilità, controllo scadenze, storia ed etichette.
enum TraceabilityRecordSupport {

    // MARK: - Filtri modulo

    /// Alimento in ingresso nel hub tracciabilità (esclude batch produzione e chiusure operative).
    static func isHubRecord(_ record: TraceabilityRecord) -> Bool {
        record.isIncomingIngredientLot
            && !record.isArchived
            && record.productStatus != .rejected
            && record.productStatus != .used
    }

    /// Voce attiva in Controllo scadenze (ingresso + produzione finita).
    /// Include lotti senza data scadenza; esclude chiusure (terminato / scaduto / scartato / usato).
    /// La traccia resta in Storia e Documenti.
    static func isExpiryMonitored(_ record: TraceabilityRecord) -> Bool {
        guard !record.isArchived else { return false }
        switch record.productStatus {
        case .used, .rejected:
            return false
        case .available, .expired:
            return true
        }
    }

    static func isIncomingExpiryRecord(_ record: TraceabilityRecord) -> Bool {
        isExpiryMonitored(record) && record.isIncomingIngredientLot
    }

    static func isProductionExpiryRecord(_ record: TraceabilityRecord) -> Bool {
        isExpiryMonitored(record) && record.isProductionBatchOutput
    }

    /// Sorgente etichetta: solo piatti preparati ancora da gestire, con foto del piatto.
    /// Esclude alimenti in ingresso, chiusure (usato/scartato) e produzioni senza foto.
    static func isLabelTraceabilitySource(_ record: TraceabilityRecord) -> Bool {
        guard record.isProductionBatchOutput, !record.isArchived else { return false }
        switch record.productStatus {
        case .used, .rejected:
            return false
        case .available, .expired:
            break
        }
        guard let photo = record.photoData, !photo.isEmpty else { return false }
        return true
    }

    // MARK: - Etichette UI

    static func expiryTypeLabel(for record: TraceabilityRecord) -> String {
        record.isProductionBatchOutput ? "Produzione finita" : "Alimento in ingresso"
    }

    static func resolvedExpirySource(
        for record: TraceabilityRecord,
        lottoById: [UUID: LottoFoto] = [:]
    ) -> ExpirySource? {
        if let source = record.expirySource {
            if source == .shelfLifeCatalog { return .manualOperator }
            return source
        }
        if let lottoId = record.lottoFotoId,
           let lotto = lottoById[lottoId],
           lotto.expiryFromLabel {
            return .groqLabel
        }
        if record.expiryDate != nil {
            return .manualOperator
        }
        return nil
    }

    static func expirySourceLabel(
        for record: TraceabilityRecord,
        lottoById: [UUID: LottoFoto] = [:]
    ) -> String? {
        resolvedExpirySource(for: record, lottoById: lottoById)?.shortLabel
    }

    // MARK: - Foto

    static func hasPhoto(
        record: TraceabilityRecord,
        images: [ProductImage],
        lottoById: [UUID: LottoFoto]
    ) -> Bool {
        if let data = record.photoData, !data.isEmpty { return true }

        let recordImages = images
            .filter { $0.receivedItemId == record.id && !$0.isArchived }
            .sorted { $0.createdAt > $1.createdAt }

        for image in recordImages {
            if let bytes = image.imageData, !bytes.isEmpty { return true }
            if let path = image.localPath,
               FileManager.default.fileExists(atPath: path) {
                return true
            }
        }

        if let lottoId = record.lottoFotoId, let lotto = lottoById[lottoId] {
            if LottoFotoImageStorage.loadImage(at: lotto.thumbnailPath) != nil { return true }
            if LottoFotoImageStorage.loadImage(at: lotto.localPath) != nil { return true }
        }

        return false
    }
}
