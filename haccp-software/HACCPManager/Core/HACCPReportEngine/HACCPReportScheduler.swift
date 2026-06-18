//
//  HACCPReportScheduler.swift
//  HACCP Manager — Report Engine
//
//  Pianificazione "cron-style" della generazione automatica.
//
//  Su iOS l'app non può girare in background a orari arbitrari (no NSCron, no daemon).
//  Lo scheduler usa quindi una strategia *catch-up*: ogni volta che l'app diventa attiva,
//  verifica se è stato attraversato un cambio mese (pacchetto report mensili).
//
//  La generazione vera resta idempotente perché `DocumentGenerationService` riusa
//  `GenerationKey` (type+module+periodStart): nessuna duplicazione.
//

import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
final class HACCPReportScheduler: ObservableObject {
    static let shared = HACCPReportScheduler()
    private init() {}

    private let persistedTickKey = "HACCPReportEngine.lastTickAt"

    /// Data dell'ultimo "tick" andato a buon fine (catch-up baseline).
    var lastTickAt: Date? {
        get {
            if let ts = UserDefaults.standard.object(forKey: persistedTickKey) as? Date { return ts }
            return nil
        }
        set {
            UserDefaults.standard.set(newValue, forKey: persistedTickKey)
        }
    }

    /// Pianifica un tick se da `lastTickAt` ad ora è stata attraversata almeno una frontiera periodica.
    /// Da chiamare su `scenePhase == .active` (l'app torna in foreground).
    func tickIfNeeded(
        restaurant: Restaurant,
        user: LocalUser,
        modelContext: ModelContext,
        now: Date = Date(),
        force: Bool = false
    ) async {
        let previousTick = lastTickAt ?? Date.distantPast
        let crossings = boundariesCrossed(from: previousTick, to: now)

        let mustRun: Bool = {
            if force { return true }
            if !crossings.isEmpty { return true }
            // Se non è mai stato eseguito, esegui comunque.
            return lastTickAt == nil
        }()

        guard mustRun else { return }

        await HACCPReportEngine.shared.runFullArchive(
            restaurant: restaurant,
            user: user,
            in: modelContext,
            force: force
        )

        lastTickAt = now

        if !crossings.isEmpty {
            HACCPAuditManager.shared.record(
                in: modelContext,
                restaurantId: restaurant.id,
                action: .generate,
                severity: .info,
                module: "REPORT_SCHEDULER",
                subject: crossings.map(\.label).joined(separator: ","),
                entityRef: restaurant.name,
                user: user,
                details: "Frontiere attraversate dall'ultimo run: \(crossings.map(\.label).joined(separator: ", "))"
            )
        }
    }

    // MARK: - Boundaries

    enum PeriodBoundary: String, Codable {
        case monthly

        var label: String { "Mensile" }
    }

    /// Calcola se fra `from` e `to` è stato attraversato un cambio mese.
    func boundariesCrossed(from: Date, to: Date) -> [PeriodBoundary] {
        guard from < to else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "it_IT")
        calendar.timeZone = .current

        let mFrom = calendar.dateComponents([.year, .month], from: from)
        let mTo = calendar.dateComponents([.year, .month], from: to)
        if (mFrom.year, mFrom.month) != (mTo.year, mTo.month) {
            return [.monthly]
        }
        return []
    }

    // MARK: - Diagnostics

    struct NextBoundariesDescription {
        let nextMidnight: Date
        let nextSundayMidnight: Date
        let nextMonthEnd: Date
        let nextYearEnd: Date
    }

    func nextBoundaries(from now: Date = Date()) -> NextBoundariesDescription {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "it_IT")
        calendar.timeZone = .current

        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        var nextSunday = startOfTomorrow
        // 1=Sunday in Gregorian (system-dependent), trova la prossima domenica a 23:59:59.
        for _ in 0..<8 {
            if calendar.component(.weekday, from: nextSunday) == 1 { break }
            nextSunday = calendar.date(byAdding: .day, value: 1, to: nextSunday) ?? nextSunday
        }

        let endOfThisMonth: Date = {
            guard let interval = calendar.dateInterval(of: .month, for: now) else { return now }
            return interval.end
        }()

        let endOfThisYear: Date = {
            guard let interval = calendar.dateInterval(of: .year, for: now) else { return now }
            return interval.end
        }()

        return NextBoundariesDescription(
            nextMidnight: startOfTomorrow,
            nextSundayMidnight: nextSunday,
            nextMonthEnd: endOfThisMonth,
            nextYearEnd: endOfThisYear
        )
    }
}
