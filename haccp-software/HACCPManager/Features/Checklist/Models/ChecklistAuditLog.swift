import Foundation
import SwiftData

@Model
final class ChecklistAuditLog {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var userId: UUID
    var userName: String
    var action: String
    var module: String
    var entityId: UUID
    var details: String?
    var timestamp: Date

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        userId: UUID,
        userName: String,
        action: String,
        module: String = "CHECKLIST",
        entityId: UUID,
        details: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.userId = userId
        self.userName = userName
        self.action = action
        self.module = module
        self.entityId = entityId
        self.details = details
        self.timestamp = timestamp
    }
}
