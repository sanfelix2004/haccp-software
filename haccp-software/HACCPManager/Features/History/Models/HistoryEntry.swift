import Foundation

struct HistoryEntryDetail: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

/// Riga alimento in ingresso sotto un piatto in Storia → Tracciabilità.
struct HistoryTraceabilityIngredient: Identifiable, Equatable {
    let id: UUID
    let name: String
    let lotCode: String
    let supplier: String
    let expiryText: String
    let operatorName: String
    let hasCriticality: Bool
}

struct HistoryEntry: Identifiable, Equatable {
    let id: String
    let module: HistoryModule
    let title: String
    let category: String
    let status: String
    let operatorName: String
    let date: Date
    let details: [HistoryEntryDetail]
    let hasCriticality: Bool
    /// Se valorizzato, la card mostra il piatto con alimenti espandibili.
    var traceabilityIngredients: [HistoryTraceabilityIngredient]? = nil
    /// Lotto scaduto in attesa di chiusura operatore (usato/scartato).
    var pendingTraceabilityRecordId: UUID? = nil
    var photoData: Data? = nil

    static func == (lhs: HistoryEntry, rhs: HistoryEntry) -> Bool {
        lhs.id == rhs.id
            && lhs.status == rhs.status
            && lhs.hasCriticality == rhs.hasCriticality
            && lhs.traceabilityIngredients == rhs.traceabilityIngredients
            && lhs.pendingTraceabilityRecordId == rhs.pendingTraceabilityRecordId
            && lhs.photoData == rhs.photoData
            && lhs.details.count == rhs.details.count
    }

    var searchText: String {
        var parts = [module.rawValue, title, category, status, operatorName]
        parts += details.flatMap { [$0.label, $0.value] }
        if let traceabilityIngredients {
            parts += traceabilityIngredients.flatMap { [$0.name, $0.lotCode, $0.supplier, $0.expiryText] }
        }
        return parts.joined(separator: " ")
    }
}
