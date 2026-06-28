//
//  ModelContext+SafeSave.swift
//  Salvataggi SwiftData senza crash — graceful degradation.
//

import Foundation
import SwiftData

extension ModelContext {

    /// Salva senza propagare errori; ritorna `false` se il persist fallisce.
    @discardableResult
    func saveSafely(operation: String = "save") -> Bool {
        do {
            try save()
            return true
        } catch {
            #if DEBUG
            print("[SwiftData] \(operation) failed: \(error.localizedDescription)")
            #endif
            return false
        }
    }
}

enum SwiftDataOperationError: LocalizedError {
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let operation):
            return "Impossibile salvare i dati (\(operation)). Riprova tra poco."
        }
    }
}

/// Esegue un blocco di scrittura e salva in modo sicuro.
@MainActor
enum ModelContextWriter {

    @discardableResult
    static func perform(
        context: ModelContext,
        operation: String,
        _ work: () throws -> Void
    ) -> Bool {
        do {
            try work()
            return context.saveSafely(operation: operation)
        } catch {
            #if DEBUG
            print("[SwiftData] \(operation) work failed: \(error.localizedDescription)")
            #endif
            return false
        }
    }
}
