//
//  MonthlyDocumentUpdateTrigger.swift
//  HACCP Manager — Report Engine
//
//  Trigger debounced per la compilazione progressiva dei documenti mensili.
//
//  Quando l'utente svolge attività operative (inserimento ricezioni, temperature,
//  checklist, ecc.), questo trigger pianifica il ricalcolo dei PDF del mese corrente
//  con un debounce di 45 secondi per evitare rigenerazioni eccessive.
//
//  Uso tipico (da qualsiasi modulo operativo, dopo modelContext.save()):
//
//    MonthlyDocumentUpdateTrigger.shared.notifyDataChanged(
//        restaurantId: restaurantId,
//        user: user,
//        modelContext: modelContext
//    )
//

import Foundation
import SwiftData

/// Notifica al Report Engine che i dati sono cambiati e che i documenti
/// del mese corrente devono essere aggiornati.
///
/// Implementa un debounce di 45s: chiamate multiple ravvicinate producono
/// un solo ricalcolo, garantendo performance senza perdere aggiornamenti.
@MainActor
final class MonthlyDocumentUpdateTrigger {
    static let shared = MonthlyDocumentUpdateTrigger()

    private var pendingTask: Task<Void, Never>?

    /// Secondi di attesa prima dell'esecuzione del ricalcolo (configurabile per test).
    var debounceSeconds: TimeInterval = 45

    private init() {}

    /// Pianifica un aggiornamento incrementale dell'archivio PDF.
    /// Chiamate ravvicinate vengono aggregate in un'unica esecuzione.
    ///
    /// - Parameters:
    ///   - restaurantId: ID del ristorante i cui documenti devono essere aggiornati.
    ///   - user: Utente corrente (per audit trail).
    ///   - modelContext: Contesto SwiftData da cui leggere e scrivere i dati.
    ///   - delay: Secondi di attesa prima dell'esecuzione (default: usa `debounceSeconds`).
    func notifyDataChanged(
        restaurantId: UUID,
        user: LocalUser,
        modelContext: ModelContext,
        delay: TimeInterval? = nil
    ) {
        pendingTask?.cancel()
        let effectiveDelay = delay ?? debounceSeconds
        pendingTask = Task { @MainActor in
            let nanos = UInt64(max(0, effectiveDelay) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }

            let restaurants = (try? modelContext.fetch(FetchDescriptor<Restaurant>())) ?? []
            guard let restaurant = restaurants.first(where: { $0.id == restaurantId }) else { return }

            // Usa il motore completo per garantire anche la rotazione mensile
            // se l'app è rimasta aperta a cavallo della mezzanotte di fine mese.
            _ = await HACCPReportEngine.shared.runFullArchive(
                restaurant: restaurant,
                user: user,
                in: modelContext,
                force: true
            )
        }
    }

    /// Cancella eventuale aggiornamento in sospeso (es. al logout o cambio ristorante).
    func cancelPending() {
        pendingTask?.cancel()
        pendingTask = nil
    }
}
