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
        case .ritirato: return "Ritirato"
        case .scartato: return "Scartato"
        }
    }

    var subtitle: String {
        switch self {
        case .ritirato: return "Prodotto rimosso dalle scorte operative"
        case .scartato: return "Prodotto eliminato / non utilizzabile"
        }
    }
}
