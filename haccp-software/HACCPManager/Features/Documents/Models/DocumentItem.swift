import Foundation
import SwiftData

@Model
final class DocumentItem {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var folderId: UUID
    var fileName: String
    var localPath: String
    var createdAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var notes: String?
    var operatorSignature: String?

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        folderId: UUID,
        fileName: String,
        localPath: String,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        notes: String? = nil,
        operatorSignature: String? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.folderId = folderId
        self.fileName = fileName
        self.localPath = localPath
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.notes = notes
        self.operatorSignature = operatorSignature
    }
}
