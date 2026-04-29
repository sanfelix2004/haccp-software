import Foundation
import SwiftUI

enum ChecklistCategory: String, Codable, CaseIterable {
    case opening = "OPENING"
    case closing = "CLOSING"
    case cleaning = "CLEANING"
    case personalHygiene = "PERSONAL_HYGIENE"
    case foodStorage = "FOOD_STORAGE"
    case foodPreparation = "FOOD_PREPARATION"
    case crossContamination = "CROSS_CONTAMINATION"
    case allergens = "ALLERGENS"
    case receivingGoods = "RECEIVING_GOODS"
    case waste = "WASTE"
    case equipment = "EQUIPMENT"
    case custom = "CUSTOM"

    var label: String {
        switch self {
        case .opening: return "Apertura"
        case .closing: return "Chiusura"
        case .cleaning: return "Pulizie"
        case .personalHygiene: return "Igiene personale"
        case .foodStorage: return "Conservazione alimenti"
        case .foodPreparation: return "Preparazione alimenti"
        case .crossContamination: return "Contaminazione crociata"
        case .allergens: return "Allergeni"
        case .receivingGoods: return "Ricevimento merci"
        case .waste: return "Rifiuti"
        case .equipment: return "Attrezzature"
        case .custom: return "Personalizzata"
        }
    }
}

enum ChecklistFrequency: String, Codable, CaseIterable {
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"
    case onDemand = "ON_DEMAND"
    case custom = "CUSTOM"

    var label: String {
        switch self {
        case .daily: return "Giornaliera"
        case .weekly: return "Settimanale"
        case .monthly: return "Mensile"
        case .onDemand: return "Su richiesta"
        case .custom: return "Personalizzata"
        }
    }
}

enum ChecklistItemType: String, Codable, CaseIterable {
    case yesNo = "YES_NO"
    case passFail = "PASS_FAIL"
    case doneNotDone = "DONE_NOT_DONE"
    case text = "TEXT"
    case number = "NUMBER"
    case temperatureLink = "TEMPERATURE_LINK"
    case photoOptionalFuture = "PHOTO_OPTIONAL_FUTURE"
}

enum ChecklistRunStatus: String, Codable, CaseIterable {
    case notStarted = "NOT_STARTED"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case overdue = "OVERDUE"
    case failed = "FAILED"
    case archived = "ARCHIVED"

    var label: String {
        switch self {
        case .notStarted: return "Non iniziata"
        case .inProgress: return "In corso"
        case .completed: return "Completata"
        case .overdue: return "In ritardo"
        case .failed: return "Fallita"
        case .archived: return "Archiviata"
        }
    }

    var color: Color {
        switch self {
        case .completed: return .green
        case .inProgress, .overdue: return .yellow
        case .failed: return .red
        case .notStarted, .archived: return .gray
        }
    }
}

enum ChecklistItemResultValue: String, Codable, CaseIterable {
    case pass = "PASS"
    case fail = "FAIL"
    case notApplicable = "NOT_APPLICABLE"
    case pending = "PENDING"

    var label: String {
        switch self {
        case .pass: return "OK"
        case .fail: return "NON OK"
        case .notApplicable: return "NON APPLICABILE"
        case .pending: return "Non completato"
        }
    }
}

enum ChecklistAlertSeverity: String, Codable {
    case warning = "WARNING"
    case high = "HIGH"
    case critical = "CRITICAL"
}

enum ChecklistAlertStatus: String, Codable {
    case active = "ATTIVA"
    case resolved = "RISOLTA"

    var label: String {
        switch self {
        case .active: return "Attiva"
        case .resolved: return "Risolta"
        }
    }
}
