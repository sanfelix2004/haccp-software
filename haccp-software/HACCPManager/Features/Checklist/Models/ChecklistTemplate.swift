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
    /// Giorno settimana (Calendar: 1=domenica … 7=sabato). Per checklist settimanali.
    var scheduleWeekday: Int?
    /// Giorno del mese (1–28). Per checklist mensili/annuali.
    var scheduleDayOfMonth: Int?
    /// Mese (1–12). Per checklist annuali.
    var scheduleMonth: Int?
    /// Pulsante compilazione rapida «tutto conforme» in esecuzione (`nil` = abilitato, per record migrati).
    var allowsBulkPass: Bool?
    /// Testo personalizzato del pulsante bulk (es. «Tutte le guarnizioni sono integre»).
    var bulkPassTitle: String?
    /// Zona/area operativa (es. «Cucina», «Cella frigo 1») per raggruppamento cross-modulo.
    var areaTag: String?
    /// Intervallo giorni per frequenza `.custom` (es. bridge pulizie personalizzate).
    var customScheduleIntervalDays: Int?
    /// Se valorizzato, modello generato dal modulo pulizie — nascosto dall'elenco modelli.
    var sourceCleaningTaskId: UUID?
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
        scheduleWeekday: Int? = nil,
        scheduleDayOfMonth: Int? = nil,
        scheduleMonth: Int? = nil,
        allowsBulkPass: Bool = true,
        bulkPassTitle: String? = nil,
        areaTag: String? = nil,
        customScheduleIntervalDays: Int? = nil,
        sourceCleaningTaskId: UUID? = nil,
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
        self.scheduleWeekday = scheduleWeekday
        self.scheduleDayOfMonth = scheduleDayOfMonth
        self.scheduleMonth = scheduleMonth
        self.allowsBulkPass = allowsBulkPass
        self.bulkPassTitle = bulkPassTitle
        self.areaTag = areaTag
        self.customScheduleIntervalDays = customScheduleIntervalDays
        self.sourceCleaningTaskId = sourceCleaningTaskId
        self.isActive = isActive
        self.isSuggestedLibrary = isSuggestedLibrary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdByUserId = createdByUserId
    }
}

extension ChecklistTemplate {
    static let cleaningCategoryRawValue = ChecklistCategory.cleaning.rawValue

    var isCleaningBridge: Bool { sourceCleaningTaskId != nil }

    /// Template del modulo pulizie (bridge o categoria dedicata).
    var isCleaningModule: Bool { category == .cleaning || isCleaningBridge }

    /// Filtro persistito per fetch SwiftData — non usare `isCleaningModule` nei `#Predicate`.
    var matchesCleaningModuleFilter: Bool {
        categoryRaw == Self.cleaningCategoryRawValue || sourceCleaningTaskId != nil
    }

    var supportsBulkPass: Bool { allowsBulkPass ?? true }

    /// Frequenza normalizzata per il motore periodico (include intervallo custom pulizie).
    var schedulingFrequencyKind: PeriodicFrequencyKind {
        if frequency == .custom, let days = customScheduleIntervalDays {
            return .custom(days: max(days, 1))
        }
        return frequency.periodicKind
    }
}
