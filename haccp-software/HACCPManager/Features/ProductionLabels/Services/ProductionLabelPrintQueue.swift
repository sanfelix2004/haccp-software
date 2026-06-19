//
//  ProductionLabelPrintQueue.swift
//  Coda stampa etichette → stampante CLABEL Bluetooth.
//

import Foundation
import Combine
import SwiftData

struct ProductionLabelPrintJob: Identifiable, Equatable {
    let id: UUID
    let labelId: UUID
    let createdAt: Date
    var copies: Int
    var countAsReprint: Bool
}

@MainActor
final class ProductionLabelPrintQueue: ObservableObject {
    static let shared = ProductionLabelPrintQueue()

    @Published private(set) var pendingJobs: [ProductionLabelPrintJob] = []
    @Published private(set) var isProcessing = false

    private let labelService = ProductionLabelsService()

    private init() {}

    func enqueue(labelId: UUID, copies: Int = 1, countAsReprint: Bool = false) {
        pendingJobs.removeAll { $0.labelId == labelId && $0.countAsReprint == countAsReprint }
        pendingJobs.append(
            ProductionLabelPrintJob(
                id: UUID(),
                labelId: labelId,
                createdAt: Date(),
                copies: max(1, copies),
                countAsReprint: countAsReprint
            )
        )
    }

    func remove(jobId: UUID) {
        pendingJobs.removeAll { $0.id == jobId }
    }

    func clear() {
        pendingJobs.removeAll()
    }

    /// Stampa subito se la stampante è pronta, altrimenti accoda e prova a svuotare la coda.
    func schedulePrint(
        label: ProductionLabelRecord,
        restaurantName: String?,
        modelContext: ModelContext,
        countAsReprint: Bool = false,
        copies: Int = 1,
        knownLabels: [ProductionLabelRecord] = []
    ) async {
        let manager = ClabelPrinterManager.shared
        if manager.isReadyToPrint {
            do {
                try await deliver(
                    label: label,
                    restaurantName: restaurantName,
                    modelContext: modelContext,
                    countAsReprint: countAsReprint,
                    copies: copies
                )
                return
            } catch {
                manager.lastErrorMessage = error.localizedDescription
            }
        }
        enqueue(labelId: label.id, copies: copies, countAsReprint: countAsReprint)
        var labels = knownLabels
        if !labels.contains(where: { $0.id == label.id }) {
            labels.append(label)
        }
        await processPending(labels: labels, modelContext: modelContext, restaurantName: restaurantName)
    }

    func processPending(
        labels: [ProductionLabelRecord],
        modelContext: ModelContext,
        restaurantName: String? = nil
    ) async {
        guard !pendingJobs.isEmpty, !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        let settings = SettingsStorageService.shared.printer
        let manager = ClabelPrinterManager.shared

        while let job = pendingJobs.first {
            guard let label = await resolveLabel(
                id: job.labelId,
                known: labels,
                modelContext: modelContext
            ) else {
                remove(jobId: job.id)
                continue
            }
            do {
                try await deliver(
                    label: label,
                    settings: settings,
                    restaurantName: restaurantName,
                    modelContext: modelContext,
                    countAsReprint: job.countAsReprint,
                    copies: job.copies
                )
                remove(jobId: job.id)
            } catch {
                manager.lastErrorMessage = error.localizedDescription
                break
            }
        }
    }

    func printNow(
        label: ProductionLabelRecord,
        restaurantName: String? = nil,
        modelContext: ModelContext? = nil,
        countAsReprint: Bool = true,
        copies: Int = 1
    ) async throws {
        try await deliver(
            label: label,
            restaurantName: restaurantName,
            modelContext: modelContext,
            countAsReprint: countAsReprint,
            copies: copies
        )
    }

    private func deliver(
        label: ProductionLabelRecord,
        settings: LabelPrinterSettings? = nil,
        restaurantName: String? = nil,
        modelContext: ModelContext?,
        countAsReprint: Bool,
        copies: Int
    ) async throws {
        let printerSettings = settings ?? SettingsStorageService.shared.printer
        let manager = ClabelPrinterManager.shared
        for _ in 0..<max(1, copies) {
            try await manager.printWithFallback(
                label: label,
                settings: printerSettings,
                restaurantName: restaurantName
            )
        }
        if countAsReprint, let modelContext {
            try labelService.markReprinted(label, modelContext: modelContext)
        }
    }

    private func resolveLabel(
        id: UUID,
        known: [ProductionLabelRecord],
        modelContext: ModelContext
    ) async -> ProductionLabelRecord? {
        if let cached = known.first(where: { $0.id == id }) {
            return cached
        }
        return try? ProductionLabelLookupService.fetchLabel(id: id, restaurantId: nil, context: modelContext)
    }
}
