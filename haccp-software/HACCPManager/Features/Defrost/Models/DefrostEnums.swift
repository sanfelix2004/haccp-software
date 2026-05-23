//
//  DefrostEnums.swift
//

import Foundation

enum DefrostMethod: String, Codable, CaseIterable, Identifiable {
    case frigorifero = "FRIGO"
    case temperaturaControllata = "TEMP_CTRL"
    case acquaFredda = "ACQUA_FREDDA"
    case fornoMicroonde = "FORNO_MICRO"
    case altro = "ALTRO"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .frigorifero: return "In frigorifero"
        case .temperaturaControllata: return "A temperatura controllata"
        case .acquaFredda: return "In acqua fredda"
        case .fornoMicroonde: return "In forno/microonde"
        case .altro: return "Altro"
        }
    }

    static func fromStored(_ value: String) -> DefrostMethod {
        if let m = DefrostMethod(rawValue: value) { return m }
        let lower = value.lowercased()
        if lower.contains("frigo") { return .frigorifero }
        if lower.contains("acqua") { return .acquaFredda }
        if lower.contains("forno") || lower.contains("micro") { return .fornoMicroonde }
        if lower.contains("controll") { return .temperaturaControllata }
        return .altro
    }
}

enum DefrostStatus: String, Codable, CaseIterable {
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case completedWithCriticality = "COMPLETED_CRITICAL"
    case cancelled = "CANCELLED"
    case delayed = "DELAYED"

    var label: String {
        switch self {
        case .inProgress: return "In corso"
        case .completed: return "Completato"
        case .completedWithCriticality: return "Completato con criticità"
        case .cancelled: return "Annullato"
        case .delayed: return "In ritardo"
        }
    }
}

enum DefrostOutcome: String, Codable, CaseIterable {
    case conforme = "CONFORME"
    case nonConforme = "NON_CONFORME"

    var label: String {
        switch self {
        case .conforme: return "Conforme"
        case .nonConforme: return "Non conforme"
        }
    }
}
