//
//  HACCPReportScheduler.swift
//  HACCP Manager — Report Engine
//
//  Pianificazione "cron-style" della generazione automatica.
//
//  Su iOS l'app non può girare in background a orari arbitrari (no NSCron, no daemon).
//  Lo scheduler usa una strategia *catch-up*: ad ogni foreground aggiorna i PDF del mese
//  corrente (incrementale) e, se è cambiato il mese, finalizza i report del periodo precedente.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class HACCPReportScheduler: ObservableObject {
    static let shared = HACCPReportScheduler()

    private let tickKeyPrefix = "HACCPReportEngine.lastTickAt."

    private init() {}

    /// Data dell'ultimo tick andato a buon fine per il ristorante (catch-up baseline).
    func lastTickAt(restaurantId: UUID) -> Date? {
        UserDefaults.standard.object(forKey: tickKey(restaurantId: restaurantId)) as? Date
    }

    private func setLastTickAt(_ date: Date, restaurantId: UUID) {
        UserDefaults.standard.set(date, forKey: tickKey(restaurantId: restaurantId))
    }

    private func tickKey(restaurantId: UUID) -> String {
        "\(tickKeyPrefix)\(restaurantId.uuidString)"
    }

    /// Aggiorna l'archivio PDF (mese corrente incrementale + catch-up mesi chiusi).
    /// Da chiamare su `scenePhase == .active` (l'app torna in foreground).
    /// Il motore applica un debounce (~60s) salvo `force == true`.
    @discardableResult
    func tickIfNeeded(
        restaurant: Restaurant,
        user: LocalUser,
        modelContext: ModelContext,
        now: Date = Date(),
        force: Bool = false
    ) async -> Bool {
        let previousTick = lastTickAt(restaurantId: restaurant.id) ?? .distantPast
        let crossings = boundariesCrossed(from: previousTick, to: now)
        let monthCrossed = crossings.contains(.monthly)

        let didRun = await HACCPReportEngine.shared.runFullArchive(
            restaurant: restaurant,
            user: user,
            in: modelContext,
            force: force,
            monthBoundaryCrossed: monthCrossed
        )

        guard didRun else { return false }

        setLastTickAt(now, restaurantId: restaurant.id)

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

        return true
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
}
