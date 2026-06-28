//
//  ProductExpiryEvaluator.swift
//  Unica fonte di verità per giorni/scadenza/ritiro — usata da Controllo scadenze.
//

import Foundation

/// Zona operativa chef in Controllo scadenze (senza dipendenze UI).
enum ExpiryOperationalZone: Int {
    case critical = 0
    case warning = 1
    case conforming = 2

    var chefHint: String {
        switch self {
        case .critical: return "Azione immediata"
        case .warning: return "Usa oggi"
        case .conforming: return "Sotto controllo"
        }
    }
}

enum ProductExpiryEvaluator {

    /// Giorni interi dalla mezzanotte di oggi alla mezzanotte della scadenza (negativo = scaduto).
    static func daysUntilExpiry(
        _ expiryDate: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfExpiry = calendar.startOfDay(for: expiryDate)
        return calendar.dateComponents([.day], from: startOfToday, to: startOfExpiry).day ?? 0
    }

    static func isExpiredByDate(
        _ expiryDate: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        daysUntilExpiry(expiryDate, now: now, calendar: calendar) < 0
    }

    static func isDueToday(
        _ expiryDate: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        daysUntilExpiry(expiryDate, now: now, calendar: calendar) == 0
    }

    static func isSoonExpiring(
        _ expiryDate: Date,
        thresholdDays: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        let days = daysUntilExpiry(expiryDate, now: now, calendar: calendar)
        return days > 0 && days <= thresholdDays
    }

    /// Scade oggi o entro la soglia impostazioni (giorni interi, da mezzanotte).
    static func isWithinExpiryThreshold(
        _ expiryDate: Date,
        thresholdDays: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        let days = daysUntilExpiry(expiryDate, now: now, calendar: calendar)
        return days >= 0 && days <= thresholdDays
    }

    /// Lotto disponibile con scadenza imminente secondo soglia HACCP.
    static func isMonitorableExpiring(
        _ record: TraceabilityRecord,
        thresholdDays: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard record.productStatus == .available else { return false }
        guard let expiry = record.expiryDate else { return false }
        return isWithinExpiryThreshold(expiry, thresholdDays: thresholdDays, now: now, calendar: calendar)
    }

    /// Richiede attenzione operatore: scaduto, oggi o entro soglia.
    static func needsExpiryAttention(
        _ record: TraceabilityRecord,
        thresholdDays: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        if record.productStatus == .expired { return true }
        guard record.productStatus == .available, let expiry = record.expiryDate else { return false }
        if isExpiredByDate(expiry, now: now, calendar: calendar) { return true }
        return isWithinExpiryThreshold(expiry, thresholdDays: thresholdDays, now: now, calendar: calendar)
    }

    /// Lotto da chiudere con ritiro/scarto operatore.
    static func canWithdraw(_ record: TraceabilityRecord, now: Date = Date()) -> Bool {
        guard record.productStatus != .used, record.productStatus != .rejected else { return false }
        if record.productStatus == .expired { return true }
        guard let expiryDate = record.expiryDate else { return false }
        return isExpiredByDate(expiryDate, now: now)
    }

    /// Transizione automatica verso stato persistito `.expired`.
    static func shouldMarkSystemExpired(_ record: TraceabilityRecord, now: Date = Date()) -> Bool {
        guard record.productStatus != .rejected,
              record.productStatus != .used,
              record.productStatus != .expired else { return false }
        guard let expiryDate = record.expiryDate else { return false }
        return isExpiredByDate(expiryDate, now: now)
    }

    /// Stato da mostrare in UI: se la scadenza è passata il lotto è Scaduto,
  /// salvo che sia già chiuso (Usato) o respinto.
    static func effectiveDisplayStatus(
        _ record: TraceabilityRecord,
        expiryDate: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ProductStatus {
        if record.isNonCompliant || record.productStatus == .rejected { return .rejected }
        if record.productStatus == .used { return .used }
        if record.productStatus == .expired { return .expired }
        guard let expiryDate else { return record.productStatus }
        if isExpiredByDate(expiryDate, now: now, calendar: calendar) { return .expired }
        return record.productStatus
    }

    static let operationalWarningDays = 2

    static func operationalZone(
        for record: TraceabilityRecord,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ExpiryOperationalZone {
        if record.productStatus == .rejected || record.productStatus == .expired {
            return .critical
        }
        guard let expiry = record.expiryDate else { return .conforming }
        let days = daysUntilExpiry(expiry, now: now, calendar: calendar)
        if days < 0 || days == 0 { return .critical }
        if days <= operationalWarningDays { return .warning }
        return .conforming
    }

    // MARK: - FEFO (First Expired, First Out)

    /// Ordina per scadenza crescente — il primo che scade è il primo ad uscire.
    static func fefoSorted(
        _ records: [TraceabilityRecord],
        now: Date = Date()
    ) -> [TraceabilityRecord] {
        records.sorted { fefoCompare($0, $1, now: now) }
    }

    /// Confronto FEFO: attivi prima dei chiusi; poi data scadenza ascendente.
    static func fefoCompare(
        _ lhs: TraceabilityRecord,
        _ rhs: TraceabilityRecord,
        now: Date = Date()
    ) -> Bool {
        let lhsClosed = lhs.productStatus == .used || lhs.productStatus == .rejected
        let rhsClosed = rhs.productStatus == .used || rhs.productStatus == .rejected
        if lhsClosed != rhsClosed { return !lhsClosed }

        let lhsUrgency = urgencyRank(for: lhs, now: now)
        let rhsUrgency = urgencyRank(for: rhs, now: now)
        if lhsUrgency != rhsUrgency { return lhsUrgency < rhsUrgency }

        let lhsDate = lhs.expiryDate ?? .distantFuture
        let rhsDate = rhs.expiryDate ?? .distantFuture
        if lhsDate != rhsDate { return lhsDate < rhsDate }
        return lhs.productName.localizedCaseInsensitiveCompare(rhs.productName) == .orderedAscending
    }

    private static func urgencyRank(for record: TraceabilityRecord, now: Date) -> Int {
        guard let expiry = record.expiryDate else { return 90 }
        if isExpiredByDate(expiry, now: now) { return 0 }
        if isDueToday(expiry, now: now) { return 1 }
        return 10
    }
}
