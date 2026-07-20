import SwiftUI

/// Stato operativo leggibile di un lotto: Scaduto / Scartato / Usato / Terminato / …
enum TraceabilityLotOperationalStatus {
    struct Presentation: Equatable {
        let label: String
        let badgeStyle: HACCPBadgeStyle
    }

    /// Preferisce l’esito di chiusura dai log; altrimenti stato effettivo (scadenza inclusa).
    static func present(
        record: TraceabilityRecord,
        logs: [TraceabilityLog]
    ) -> Presentation {
        let life = TraceabilityLifecycleSummary.build(record: record, logs: logs)
        if let outcome = life.closure?.outcome {
            return Presentation(label: outcome, badgeStyle: style(forOutcome: outcome))
        }

        let effective = ProductExpiryEvaluator.effectiveDisplayStatus(
            record,
            expiryDate: record.expiryDate
        )
        switch effective {
        case .expired:
            return Presentation(label: "Scaduto", badgeStyle: .warning)
        case .used:
            return Presentation(label: "Usato", badgeStyle: .info)
        case .rejected:
            return Presentation(label: "Respinto", badgeStyle: .nonConforme)
        case .available:
            return Presentation(label: "Disponibile", badgeStyle: .conforme)
        }
    }

    static func style(forOutcome outcome: String) -> HACCPBadgeStyle {
        let s = outcome.lowercased()
        if s.contains("scart") || s.contains("respint") || s.contains("non conform") {
            return .nonConforme
        }
        if s.contains("scadut") {
            return .warning
        }
        if s.contains("usat") || s.contains("terminat") || s.contains("chius") {
            return .info
        }
        return .neutral
    }
}
