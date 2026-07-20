//
//  HACCPArchiveSyncCoordinator.swift
//  HACCP Manager — Report Engine
//
//  Debounce per aggiornare i PDF del mese corrente dopo modifiche ai registri operativi.
//

import Foundation
import SwiftData

/// Debounce per aggiornare i PDF del mese corrente dopo modifiche ai registri operativi.
///
/// Dopo il sync posta `kitchenProcessRecordsDidChange` così Storia/Documenti ricaricano i file aggiornati.
@MainActor
enum HACCPArchiveSyncCoordinator {
    private static var pendingTask: Task<Void, Never>?

    /// Pianifica un aggiornamento incrementale dell'archivio PDF.
    /// - Parameter delaySeconds: default 8s per burst di salvataggi; usare 1s dopo creazione produzione.
    static func requestDeferredSync(
        restaurantId: UUID,
        user: LocalUser,
        modelContext: ModelContext,
        delaySeconds: TimeInterval = 8
    ) {
        pendingTask?.cancel()
        pendingTask = Task {
            let nanos = UInt64(max(0, delaySeconds) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }

            let restaurants = (try? modelContext.fetch(FetchDescriptor<Restaurant>())) ?? []
            guard let restaurant = restaurants.first(where: { $0.id == restaurantId }) else { return }

            let didRun = await HACCPReportEngine.shared.runFullArchive(
                restaurant: restaurant,
                user: user,
                in: modelContext,
                force: true
            )
            if didRun {
                KitchenProcessNotifications.postRecordsDidChange()
            }
        }
    }
}
