//
//  ProductionLabelPrintQueue.swift
//  Coda stampa etichette → stampante CLABEL Bluetooth.
//

import Foundation
import Combine

struct ProductionLabelPrintJob: Identifiable, Equatable {
    let id: UUID
    let labelId: UUID
    let createdAt: Date
    var copies: Int
}

@MainActor
final class ProductionLabelPrintQueue: ObservableObject {
    static let shared = ProductionLabelPrintQueue()

    @Published private(set) var pendingJobs: [ProductionLabelPrintJob] = []
    @Published private(set) var isProcessing = false

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

    func processPending(labels: [ProductionLabelRecord], restaurantName: String? = nil) async {
        guard !pendingJobs.isEmpty, !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        let settings = SettingsStorageService.shared.printer
        let manager = ClabelPrinterManager.shared

        while let job = pendingJobs.first {
            guard let label = labels.first(where: { $0.id == job.labelId }) else {
                remove(jobId: job.id)
                continue
            }
            do {
                for _ in 0..<job.copies {
                    try await manager.printWithFallback(
                        label: label,
                        settings: settings,
                        restaurantName: restaurantName
                    )
                }
                remove(jobId: job.id)
            } catch {
                manager.lastErrorMessage = error.localizedDescription
                break
            }
        }
    }

    func printNow(label: ProductionLabelRecord, restaurantName: String? = nil, copies: Int = 1) async throws {
        let settings = SettingsStorageService.shared.printer
        let manager = ClabelPrinterManager.shared
        for _ in 0..<max(1, copies) {
            try await manager.printWithFallback(
                label: label,
                settings: settings,
                restaurantName: restaurantName
            )
        }
    }
}
