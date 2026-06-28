import Foundation
import SwiftData

enum TraceabilitySource: String, Codable {
    case manual = "MANUAL"
    case receipt = "RICEZIONE_MERCI"
}

enum ProductStatus: String, Codable, CaseIterable {
    case available = "AVAILABLE"
    case used = "USED"
    case expired = "EXPIRED"
    case rejected = "REJECTED"

    var label: String {
        switch self {
        case .available: return "Disponibile"
        case .used: return "Usato"
        case .expired: return "Scaduto"
        case .rejected: return "Respinto"
        }
    }
}

enum ProductImageType: String, Codable {
    /// Foto allegata a ricezione conforme o accettata senza criticità obbligatoria.
    case receiptOptional = "RECEIPT_OPTIONAL"
    /// Prova fotografica obbligatoria per non conformità (ricezione o tracciabilità).
    case nonComplianceRequired = "NON_COMPLIANCE_REQUIRED"
    /// Foto etichetta lotto per OCR in produzione/tracciabilità.
    case lotLabelOCR = "LOT_LABEL_OCR"
    @available(*, deprecated, message: "Usare receiptOptional")
    case generic = "GENERIC"
    @available(*, deprecated, message: "Usare nonComplianceRequired")
    case nonCompliance = "NON_COMPLIANCE"
}

@Model
final class TraceabilityRecord {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var productName: String
    var lotCode: String
    var supplier: String
    var sourceRaw: String = TraceabilitySource.manual.rawValue
    var goodsReceiptId: UUID?
    /// Stato conformità della ricezione collegata (allineato da Ricezione merci).
    var goodsReceiptStatusRaw: String?
    var categoryRaw: String?
    var currentStatusRaw: String?
    var productStatusRaw: String = ProductStatus.available.rawValue
    var isNonCompliant: Bool = false
    var nonComplianceNote: String?
    /// Azione correttiva registrata con la segnalazione di non conformità in tracciabilità.
    var nonComplianceCorrectiveAction: String?
    var receivedAt: Date
    var expiryDate: Date?
    /// Provenienza scadenza (OCA, shelf-life, manuale, produzione).
    var expirySourceRaw: String?
    /// Batch produzione collegato (scadenza piatto finito).
    var produzioneBatchId: UUID?
    var productionReference: String?
    var photoData: Data?
    var createdAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var notes: String?
    var operatorSignature: String?
    var nonComplianceResolvedAt: Date?
    var nonComplianceResolvedByNameSnapshot: String?
    var isArchived: Bool = false
    var archivedAt: Date?
    /// Collegamento al lotto fotografato (flusso camera).
    var lottoFotoId: UUID?

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        productName: String,
        lotCode: String,
        supplier: String,
        source: TraceabilitySource = .manual,
        goodsReceiptId: UUID? = nil,
        receivedAt: Date,
        expiryDate: Date? = nil,
        expirySource: ExpirySource? = nil,
        produzioneBatchId: UUID? = nil,
        productionReference: String? = nil,
        photoData: Data? = nil,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        notes: String? = nil,
        operatorSignature: String? = nil,
        nonComplianceResolvedAt: Date? = nil,
        nonComplianceResolvedByNameSnapshot: String? = nil,
        lottoFotoId: UUID? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.productName = productName
        self.lotCode = lotCode
        self.supplier = supplier
        self.sourceRaw = source.rawValue
        self.goodsReceiptId = goodsReceiptId
        self.receivedAt = receivedAt
        self.expiryDate = expiryDate
        self.expirySourceRaw = expirySource?.rawValue
        self.produzioneBatchId = produzioneBatchId
        self.productionReference = productionReference
        self.photoData = photoData
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.notes = notes
        self.operatorSignature = operatorSignature
        self.nonComplianceResolvedAt = nonComplianceResolvedAt
        self.nonComplianceResolvedByNameSnapshot = nonComplianceResolvedByNameSnapshot
        self.lottoFotoId = lottoFotoId
    }

    var source: TraceabilitySource {
        get { TraceabilitySource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var productStatus: ProductStatus {
        get {
            if productStatusRaw == "PARTIALLY_USED" { return .available }
            return ProductStatus(rawValue: productStatusRaw) ?? .available
        }
        set { productStatusRaw = newValue.rawValue }
    }

    var expirySource: ExpirySource? {
        get { expirySourceRaw.flatMap { ExpirySource(rawValue: $0) } }
        set { expirySourceRaw = newValue?.rawValue }
    }

    /// Lotto scaduto ancora da chiudere con ritiro/scarto operatore.
    var canBeWithdrawn: Bool {
        ProductExpiryEvaluator.canWithdraw(self)
    }

    /// Piatto finito da batch produzione (controllo scadenze) — non è un alimento in ingresso.
    var isProductionBatchOutput: Bool {
        produzioneBatchId != nil
    }

    /// Alimento in ingresso tracciato (foto lotto o registrazione manuale).
    var isIncomingIngredientLot: Bool {
        !isProductionBatchOutput
    }
}

@Model
final class ProductImage {
    @Attribute(.unique) var id: UUID
    var receivedItemId: UUID
    /// Dati immagine inline (preferito). Alternativa: `localPath`.
    var imageData: Data?
    /// Percorso file locale se l’immagine non è salvata in `imageData`.
    var localPath: String?
    var typeRaw: String
    var createdAt: Date
    var createdByUserId: UUID = UUID()
    var createdByNameSnapshot: String = ""
    var isArchived: Bool = false
    var archivedAt: Date?
    /// Se valorizzato, l'immagine appartiene alla ricezione merci (NC o documentazione).
    var goodsReceiptId: UUID?

    init(
        id: UUID = UUID(),
        receivedItemId: UUID,
        imageData: Data? = nil,
        localPath: String? = nil,
        type: ProductImageType,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        goodsReceiptId: UUID? = nil
    ) {
        self.id = id
        self.receivedItemId = receivedItemId
        self.imageData = imageData
        self.localPath = localPath
        self.typeRaw = type.storageRawValue
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.goodsReceiptId = goodsReceiptId
    }

    var type: ProductImageType {
        get { ProductImageType.fromStored(typeRaw) }
        set { typeRaw = newValue.storageRawValue }
    }
}

extension ProductImageType {
    /// Valore persistito (senza alias deprecati).
    var storageRawValue: String {
        switch self {
        case .receiptOptional: return ProductImageType.receiptOptional.rawValue
        case .nonComplianceRequired: return ProductImageType.nonComplianceRequired.rawValue
        case .lotLabelOCR: return ProductImageType.lotLabelOCR.rawValue
        case .generic: return "RECEIPT_OPTIONAL"
        case .nonCompliance: return "NON_COMPLIANCE_REQUIRED"
        }
    }

    static func fromStored(_ raw: String) -> ProductImageType {
        switch raw {
        case ProductImageType.receiptOptional.rawValue, "GENERIC":
            return .receiptOptional
        case ProductImageType.nonComplianceRequired.rawValue, "NON_COMPLIANCE":
            return .nonComplianceRequired
        case ProductImageType.lotLabelOCR.rawValue:
            return .lotLabelOCR
        default:
            return .receiptOptional
        }
    }
}
