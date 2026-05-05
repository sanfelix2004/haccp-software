import Foundation
import SwiftData

enum DocumentFolderType: String, Codable, CaseIterable {
    case root = "ROOT"
    case period = "PERIODO"
    case module = "MODULO"
    case nonConformity = "NON_CONFORMITA"
    case archive = "ARCHIVIO"
}

@Model
final class DocumentFolder {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var name: String
    var typeRaw: String = DocumentFolderType.root.rawValue
    var parentId: UUID?
    var orderIndex: Int = 0
    var createdAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var notes: String?
    var operatorSignature: String?

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        name: String,
        type: DocumentFolderType = .root,
        parentId: UUID? = nil,
        orderIndex: Int = 0,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        notes: String? = nil,
        operatorSignature: String? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.name = name
        self.typeRaw = type.rawValue
        self.parentId = parentId
        self.orderIndex = orderIndex
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.notes = notes
        self.operatorSignature = operatorSignature
    }

    var type: DocumentFolderType {
        get { DocumentFolderType(rawValue: typeRaw) ?? .root }
        set { typeRaw = newValue.rawValue }
    }
}
