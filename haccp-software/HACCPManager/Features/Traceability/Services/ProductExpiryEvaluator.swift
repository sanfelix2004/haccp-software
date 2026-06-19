//
//  ProductExpiryEvaluator.swift
//  Unica fonte di verità per giorni/scadenza/ritiro lotti tracciati.
//

import Foundation

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
}
