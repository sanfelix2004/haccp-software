import Foundation
import SwiftData

/// Ingrediente tracciato via foto OCR all'interno di un batch produzione.
@Model
final class IngredienteTracciato {
    @Attribute(.unique) var id: UUID
    var produzioneBatchId: UUID
    var restaurantId: UUID
    var sequenceIndex: Int
    var photoId: UUID?
    var lotCodeExtracted: String?
    /// Nome ingrediente confermato (OCR o selezione manuale).
    var ingredientNameAssigned: String?
    /// Collegamento all'alimento in ingresso (catalogo).
    var productTemplateId: UUID?
    var ingredientNameHint: String?
    var ocrConfidence: Double?
    var ocrRawText: String?
    var statoRaw: String
    var createdAt: Date
    /// Timestamp registrazione automatica lotto (legame HACCP).
    var lotRegisteredAt: Date?

    init(
        id: UUID = UUID(),
        produzioneBatchId: UUID,
        restaurantId: UUID,
        sequenceIndex: Int,
        photoId: UUID? = nil,
        lotCodeExtracted: String? = nil,
        ingredientNameAssigned: String? = nil,
        productTemplateId: UUID? = nil,
        ingredientNameHint: String? = nil,
        ocrConfidence: Double? = nil,
        ocrRawText: String? = nil,
        stato: IngredienteTracciatoStato = .ocrInAttesa,
        createdAt: Date = Date(),
        lotRegisteredAt: Date? = nil
    ) {
        self.id = id
        self.produzioneBatchId = produzioneBatchId
        self.restaurantId = restaurantId
        self.sequenceIndex = sequenceIndex
        self.photoId = photoId
        self.lotCodeExtracted = lotCodeExtracted
        self.ingredientNameAssigned = ingredientNameAssigned
        self.productTemplateId = productTemplateId
        self.ingredientNameHint = ingredientNameHint
        self.ocrConfidence = ocrConfidence
        self.ocrRawText = ocrRawText
        self.statoRaw = stato.rawValue
        self.createdAt = createdAt
        self.lotRegisteredAt = lotRegisteredAt
    }

    var stato: IngredienteTracciatoStato {
        get { IngredienteTracciatoStato(rawValue: statoRaw) ?? .ocrInAttesa }
        set { statoRaw = newValue.rawValue }
    }

    /// Legame Produzione → Foto → Lotto (quando il lotto è registrato).
    func lotBinding(productionId: UUID) -> ProductionLotBinding? {
        guard let lotCode = lotCodeExtracted?.trimmingCharacters(in: .whitespacesAndNewlines),
              !lotCode.isEmpty else { return nil }
        return ProductionLotBinding(
            produzioneBatchId: produzioneBatchId,
            productionId: productionId,
            photoId: photoId,
            lotCode: lotCode,
            registeredAt: lotRegisteredAt ?? createdAt
        )
    }
}
