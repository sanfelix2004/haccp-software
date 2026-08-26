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
    var photoData: Data? = nil
    /// Es. Scaduto / Scartato / Usato.
    var statusLabel: String? = nil
    /// Codice foto da data/ora scatto (es. F-20260826-112345).
    var photoCaptureCode: String? = nil
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
    /// Codice lotto interno produzione (YYYYMMDD-XX).
    var internalLotCode: String? = nil
    /// ID batch produzione per aprire il report completo.
    var produzioneBatchId: UUID? = nil
    /// Record tracciabilità da soft-delete dallo storico (singolo lotto).
    var historyRemovalRecordId: UUID? = nil
    /// MASTER può eliminare questa produzione dallo storico (cancellazione reale).
    var allowsHistoryRemoval: Bool = false
    /// Giorni di conservazione copiati sull’istanza di produzione.
    var shelfLifeDays: Int? = nil
    /// Scadenza calcolata e salvata sulla produzione.
    var expiryDate: Date? = nil

    static func == (lhs: HistoryEntry, rhs: HistoryEntry) -> Bool {
        lhs.id == rhs.id
            && lhs.status == rhs.status
            && lhs.hasCriticality == rhs.hasCriticality
            && lhs.traceabilityIngredients == rhs.traceabilityIngredients
            && lhs.pendingTraceabilityRecordId == rhs.pendingTraceabilityRecordId
            && lhs.photoData == rhs.photoData
            && lhs.internalLotCode == rhs.internalLotCode
            && lhs.produzioneBatchId == rhs.produzioneBatchId
            && lhs.historyRemovalRecordId == rhs.historyRemovalRecordId
            && lhs.allowsHistoryRemoval == rhs.allowsHistoryRemoval
            && lhs.shelfLifeDays == rhs.shelfLifeDays
            && lhs.expiryDate == rhs.expiryDate
            && lhs.details.count == rhs.details.count
    }

    var searchText: String {
        var parts = [module.rawValue, title, category, status, operatorName]
        parts += details.flatMap { [$0.label, $0.value] }
        if let internalLotCode { parts.append(internalLotCode) }
        if let traceabilityIngredients {
            parts += traceabilityIngredients.flatMap {
                [$0.name, $0.lotCode, $0.supplier, $0.expiryText, $0.photoCaptureCode].compactMap { $0 }
            }
        }
        return parts.joined(separator: " ")
    }
}
