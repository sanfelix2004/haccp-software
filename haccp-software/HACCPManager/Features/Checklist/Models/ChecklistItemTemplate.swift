import Foundation
import SwiftData

@Model
final class ChecklistItemTemplate {
    @Attribute(.unique) var id: UUID
    var checklistTemplateId: UUID
    var title: String
    var itemDescription: String
    var typeRaw: String
    var isRequired: Bool
    var orderIndex: Int
    var requiresNoteIfFailed: Bool
    var requiresPhotoIfFailed: Bool
    var createdAt: Date

    var type: ChecklistItemType {
        get { ChecklistItemType(rawValue: typeRaw) ?? .passFail }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        checklistTemplateId: UUID,
        title: String,
        itemDescription: String,
        type: ChecklistItemType,
        isRequired: Bool,
        orderIndex: Int,
        requiresNoteIfFailed: Bool,
        requiresPhotoIfFailed: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.checklistTemplateId = checklistTemplateId
        self.title = title
        self.itemDescription = itemDescription
        self.typeRaw = type.rawValue
        self.isRequired = isRequired
        self.orderIndex = orderIndex
        self.requiresNoteIfFailed = requiresNoteIfFailed
        self.requiresPhotoIfFailed = requiresPhotoIfFailed
        self.createdAt = createdAt
    }
}
