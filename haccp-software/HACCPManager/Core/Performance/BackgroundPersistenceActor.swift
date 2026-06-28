//
//  BackgroundPersistenceActor.swift
//  Solo operazioni batch off-main che NON restituiscono @Model alla UI.
//  I fetch per le viste usano sempre il ModelContext principale (MainActor).
//

import Foundation
import SwiftData

@ModelActor
actor BackgroundPersistenceActor {

    /// Archivia un batch di record storici; ritorna quanti record sono stati archiviati.
    func archiveRestaurant(restaurantId: UUID) -> Int {
        DataArchiveService.archiveRestaurant(context: modelContext, restaurantId: restaurantId)
    }

    @discardableResult
    func saveAfterArchive() -> Bool {
        modelContext.saveSafely(operation: "archive")
    }
}
