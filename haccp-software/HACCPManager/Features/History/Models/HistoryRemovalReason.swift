import Foundation

/// Motivo rimozione dallo storico operativo (MASTER).
/// `.error` = cancellazione definitiva; altri casi = soft-hide con audit Documenti.
enum HistoryRemovalReason: String, CaseIterable, Identifiable, Codable {
    case finished = "FINISHED"
    case expired = "EXPIRED"
    case error = "ERROR"
    case other = "OTHER"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .finished: return "Terminata / consumata"
        case .expired: return "Scaduta (chiusura)"
        case .error: return "Errore di registrazione"
        case .other: return "Altro"
        }
    }

    var subtitle: String {
        switch self {
        case .finished: return "Il piatto o il lotto è stato consumato o venduto."
        case .expired: return "Scaduto e chiuso; resta la traccia in Documenti."
        case .error: return "Registrazione sbagliata: cancellazione definitiva (non resta in Documenti)."
        case .other: return "Specifica il motivo nella nota."
        }
    }

    /// Per `other` la nota è obbligatoria.
    var requiresNote: Bool { self == .other }

    var auditLabel: String { label }
}
