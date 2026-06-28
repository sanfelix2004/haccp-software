import Foundation
import SwiftData

/// Evento lotto: foto etichetta + testo OCR/manuale + alimento in ingresso.
@Model
final class LottoFoto {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    /// Percorso file immagine originale in Documents.
    var localPath: String
    /// Percorso thumbnail compressa per le liste.
    var thumbnailPath: String?
    var testoLottoOCR: String?
    var testoLottoFinale: String?
    var dataScatto: Date
    var alimentoIngressoID: UUID?
    var alimentoIngressoNameSnapshot: String?
    var expiryDate: Date?
    /// `true` se l'operatore ha modificato manualmente la scadenza proposta.
    var expiryOverridden: Bool
    /// `true` se la scadenza è stata letta dall'etichetta (Groq AI).
    var expiryFromLabel: Bool = false
    /// Raggruppa gli scatti della stessa sessione prima dell'associazione a produzione.
    var traceabilitySessionId: UUID?
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var createdAt: Date
    var isArchived: Bool
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        localPath: String,
        thumbnailPath: String? = nil,
        testoLottoOCR: String? = nil,
        testoLottoFinale: String? = nil,
        dataScatto: Date = Date(),
        alimentoIngressoID: UUID? = nil,
        alimentoIngressoNameSnapshot: String? = nil,
        expiryDate: Date? = nil,
        expiryOverridden: Bool = false,
        expiryFromLabel: Bool = false,
        traceabilitySessionId: UUID? = nil,
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        createdAt: Date = Date(),
        isArchived: Bool = false,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.localPath = localPath
        self.thumbnailPath = thumbnailPath
        self.testoLottoOCR = testoLottoOCR
        self.testoLottoFinale = testoLottoFinale
        self.dataScatto = dataScatto
        self.alimentoIngressoID = alimentoIngressoID
        self.alimentoIngressoNameSnapshot = alimentoIngressoNameSnapshot
        self.expiryDate = expiryDate
        self.expiryOverridden = expiryOverridden
        self.expiryFromLabel = expiryFromLabel
        self.traceabilitySessionId = traceabilitySessionId
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.archivedAt = archivedAt
    }

    var lotCode: String? {
        let final = testoLottoFinale?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let final, !final.isEmpty { return final }
        let ocr = testoLottoOCR?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let ocr, !ocr.isEmpty { return ocr }
        return nil
    }

    var isConfirmed: Bool {
        alimentoIngressoID != nil
    }
}
