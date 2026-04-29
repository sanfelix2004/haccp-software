import Foundation
import SwiftData

@Model
final class ChecklistTemplate {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var title: String
    var checklistDescription: String
    var categoryRaw: String
    var frequencyRaw: String
    var scheduledHour: Int?
    var scheduledMinute: Int?
    var isActive: Bool
    var isSuggestedLibrary: Bool
    var createdAt: Date
    var updatedAt: Date
    var createdByUserId: UUID

    var category: ChecklistCategory {
        get { ChecklistCategory(rawValue: categoryRaw) ?? .custom }
        set { categoryRaw = newValue.rawValue }
    }

    var frequency: ChecklistFrequency {
        get { ChecklistFrequency(rawValue: frequencyRaw) ?? .onDemand }
        set { frequencyRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        title: String,
        checklistDescription: String,
        category: ChecklistCategory,
        frequency: ChecklistFrequency,
        scheduledHour: Int? = nil,
        scheduledMinute: Int? = nil,
        isActive: Bool = true,
        isSuggestedLibrary: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdByUserId: UUID
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.title = title
        self.checklistDescription = checklistDescription
        self.categoryRaw = category.rawValue
        self.frequencyRaw = frequency.rawValue
        self.scheduledHour = scheduledHour
        self.scheduledMinute = scheduledMinute
        self.isActive = isActive
        self.isSuggestedLibrary = isSuggestedLibrary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdByUserId = createdByUserId
    }
}
