import Foundation
import SwiftData

@Model
final class ChecklistItemResult {
    @Attribute(.unique) var id: UUID
    var checklistRunId: UUID
    var itemTemplateId: UUID
    var titleSnapshot: String
    var resultRaw: String
    var note: String?
    var completedAt: Date?
    var completedByUserId: UUID?
    var orderIndex: Int

    var result: ChecklistItemResultValue {
        get { ChecklistItemResultValue(rawValue: resultRaw) ?? .pending }
        set { resultRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        checklistRunId: UUID,
        itemTemplateId: UUID,
        titleSnapshot: String,
        result: ChecklistItemResultValue = .pending,
        note: String? = nil,
        completedAt: Date? = nil,
        completedByUserId: UUID? = nil,
        orderIndex: Int
    ) {
        self.id = id
        self.checklistRunId = checklistRunId
        self.itemTemplateId = itemTemplateId
        self.titleSnapshot = titleSnapshot
        self.resultRaw = result.rawValue
        self.note = note
        self.completedAt = completedAt
        self.completedByUserId = completedByUserId
        self.orderIndex = orderIndex
    }
}
