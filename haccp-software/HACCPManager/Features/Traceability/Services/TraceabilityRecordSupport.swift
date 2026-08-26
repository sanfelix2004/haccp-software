import Foundation
import SwiftData

/// Regole condivise per hub tracciabilità, controllo scadenze, storia ed etichette.
enum TraceabilityRecordSupport {

    /// Nome bozza foto etichetta prima dell’assegnazione ad Alimento Produzione.
    static let kitchenLabelDraftName = "Etichetta"

    /// Giorni in cui una chiusura resta visibile in Controllo scadenze, poi sparisce.
    static let expiryClosureGraceDays = 1

    // MARK: - Filtri modulo

    /// Foto etichetta del flusso cucina (bozza o già assegnata). Non è un alimento in ingresso da scadenze.
    static func isKitchenLabelCapture(_ record: TraceabilityRecord) -> Bool {
        guard record.isIncomingIngredientLot, record.lottoFotoId != nil else { return false }
        if isUnassignedKitchenLabelDraft(record) { return true }
        let name = record.productName
        if name.hasPrefix("\(kitchenLabelDraftName) F-") { return true }
        if name.hasPrefix("Etichetta lotto") { return true }
        return false
    }

    /// Foto scattata in Tracciabilità ma non ancora collegata a una produzione.
    /// Non deve comparire in Scadenze, giacenza PDF o hub come alimento “vero”.
    static func isUnassignedKitchenLabelDraft(_ record: TraceabilityRecord) -> Bool {
        guard record.isIncomingIngredientLot, !record.isArchived else { return false }
        guard record.lottoFotoId != nil else { return false }
        return record.productName == kitchenLabelDraftName
            || record.productName == "Etichetta lotto" // legacy placeholder
    }

    /// Chiusura operativa: terminato / usato / scartato / respinto.
    static func isOperationallyClosed(_ record: TraceabilityRecord) -> Bool {
        switch record.productStatus {
        case .used, .rejected:
            return true
        case .available, .expired:
            return false
        }
    }

    /// Ancora nel periodo di grazia (1 giorno) in Controllo scadenze dopo la chiusura.
    static func isWithinClosureGracePeriod(
        _ record: TraceabilityRecord,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard isOperationallyClosed(record) else { return false }
        guard let closedAt = record.operationalClosedAt else { return false }
        guard let deadline = calendar.date(
            byAdding: .day,
            value: expiryClosureGraceDays,
            to: closedAt
        ) else { return false }
        return now < deadline
    }

    /// Alimento in ingresso nel hub tracciabilità.
    /// Esclude chiusure (terminato/scaduto/scartato), lotti già scaduti per data e bozze foto non assegnate.
    static func isHubRecord(_ record: TraceabilityRecord) -> Bool {
        guard record.isIncomingIngredientLot, !record.isArchived else { return false }
        guard !isUnassignedKitchenLabelDraft(record) else { return false }
        guard record.productStatus == .available else { return false }
        if let expiry = record.expiryDate, ProductExpiryEvaluator.isExpiredByDate(expiry) {
            return false
        }
        return true
    }

    /// Voce in Controllo scadenze: aperti + scaduti da chiudere + chiusure da meno di 1 giorno.
    /// Dopo il grace period spariscono qui; restano per sempre in Storia e Documenti.
    static func isExpiryMonitored(
        _ record: TraceabilityRecord,
        now: Date = Date()
    ) -> Bool {
        guard !record.isArchived else { return false }
        guard !isKitchenLabelCapture(record) else { return false }
        switch record.productStatus {
        case .available, .expired:
            return true
        case .used, .rejected:
            return isWithinClosureGracePeriod(record, now: now)
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
