//
//  ProductionLabelPrintQueue.swift
//  Stub per futura stampa Bluetooth (termica).
//

import Foundation
import Combine

struct ProductionLabelPrintJob: Identifiable, Equatable {
    let id: UUID
    let labelId: UUID
    let createdAt: Date
    var copies: Int
}

/// Coda locale in memoria — in futuro collegata a driver Bluetooth.
@MainActor
final class ProductionLabelPrintQueue: ObservableObject {
    static let shared = ProductionLabelPrintQueue()

    @Published private(set) var pendingJobs: [ProductionLabelPrintJob] = []

    private init() {}

    func enqueue(labelId: UUID, copies: Int = 1) {
        let job = ProductionLabelPrintJob(
            id: UUID(),
            labelId: labelId,
            createdAt: Date(),
            copies: max(1, copies)
        )
        pendingJobs.append(job)
    }

    func remove(jobId: UUID) {
        pendingJobs.removeAll { $0.id == jobId }
    }

    func clear() {
        pendingJobs.removeAll()
    }

    /// Placeholder: quando sarà disponibile il modulo Bluetooth, processare qui.
    func processNext() async -> Bool {
        guard !pendingJobs.isEmpty else { return false }
        pendingJobs.removeFirst()
        return true
    }
}
