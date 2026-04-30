import Foundation
import SwiftData

enum TraceabilitySource: String, Codable {
    case manual = "MANUAL"
    case receipt = "RICEZIONE_MERCI"
}

enum ProductStatus: String, Codable, CaseIterable {
    case available = "AVAILABLE"
    case partiallyUsed = "PARTIALLY_USED"
    case used = "USED"
    case expired = "EXPIRED"
    case rejected = "REJECTED"

    var label: String {
        switch self {
        case .available: return "Disponibile"
        case .partiallyUsed: return "Usato parzialmente"
        case .used: return "Usato"
        case .expired: return "Scaduto"
        case .rejected: return "Respinto"
        }
    }
}

enum ProductImageType: String, Codable, CaseIterable {
    case generic = "GENERIC"
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
    var categoryRaw: String?
    var currentStatusRaw: String?
    var productStatusRaw: String = ProductStatus.available.rawValue
    var isNonCompliant: Bool = false
    var nonComplianceNote: String?
    var receivedAt: Date
    var expiryDate: Date?
    var productionReference: String?
    var photoData: Data?
    var createdAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var notes: String?
    var operatorSignature: String?

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
        productionReference: String? = nil,
        photoData: Data? = nil,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        notes: String? = nil,
        operatorSignature: String? = nil
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
        self.productionReference = productionReference
        self.photoData = photoData
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.notes = notes
        self.operatorSignature = operatorSignature
    }

    var source: TraceabilitySource {
        get { TraceabilitySource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var productStatus: ProductStatus {
        get { ProductStatus(rawValue: productStatusRaw) ?? .available }
        set { productStatusRaw = newValue.rawValue }
    }
}

@Model
final class ProductImage {
    @Attribute(.unique) var id: UUID
    var receivedItemId: UUID
    var imageData: Data
    var typeRaw: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        receivedItemId: UUID,
        imageData: Data,
        type: ProductImageType,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.receivedItemId = receivedItemId
        self.imageData = imageData
        self.typeRaw = type.rawValue
        self.createdAt = createdAt
    }

    var type: ProductImageType {
        get { ProductImageType(rawValue: typeRaw) ?? .generic }
        set { typeRaw = newValue.rawValue }
    }
}
