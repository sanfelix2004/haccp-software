//
//  TraceabilityWithdrawal.swift
//

import Foundation

enum TraceabilityWithdrawalKind: String, CaseIterable, Identifiable, Codable {
    case ritirato = "RITIRATO"
    case scartato = "SCARTATO"
    case scaduto = "SCADUTO"

    var id: String { rawValue }

    var label: String {
        switch self {
                case .ritirato: return "Terminato"
        case .scartato: return "Scartato"
        case .scaduto: return "Scaduto"
        }
    }

    var subtitle: String {
        switch self {
        case .ritirato: return "Consumato, venduto o finito in cucina"
        case .scartato: return "Eliminato / non utilizzabile — indica la motivazione"
        case .scaduto: return "Eliminato perché scaduto (nessuna motivazione richiesta)"
        }
    }

    var requiresNote: Bool {
        switch self {
        case .ritirato, .scaduto: return false
        case .scartato: return true
        }
    }

    /// Terminato (ritirato) solo Storia; scarto/scaduto anche Documenti.
    var recordsInDocuments: Bool {
        switch self {
        case .ritirato: return false
        case .scartato, .scaduto: return true
        }
    }

    var closedProductStatus: ProductStatus {
        switch self {
        case .ritirato, .scaduto: return .used
        case .scartato: return .rejected
        }
    }
}
