//
//  TraceabilityWithdrawal.swift
//

import Foundation

enum TraceabilityWithdrawalKind: String, CaseIterable, Identifiable, Codable {
    case ritirato = "RITIRATO"
    case scartato = "SCARTATO"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ritirato: return "Usato"
        case .scartato: return "Scartato"
        }
    }

    var subtitle: String {
        switch self {
        case .ritirato: return "Prodotto utilizzato in cucina"
        case .scartato: return "Prodotto eliminato / non utilizzabile"
        }
    }
}
