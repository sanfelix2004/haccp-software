//
//  AnalyticsDataStore.swift
//  Campioni grafici caricati on-demand — fetch off-main, presentation value types.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class AnalyticsDataStore: ObservableObject {
    @Published private(set) var presentation = AnalyticsPresentation.empty
    @Published private(set) var isLoading = false
    @Published private(set) var dataRevision = UUID()

    private var loadTask: Task<Void, Never>?
    private var rebuildTask: Task<Void, Never>?
    private var reloadPolicy = DataStoreReloadPolicy()
    private var backgroundLoader: AnalyticsBackgroundLoader?

    private var isEmpty: Bool {
        !presentation.hasAnyData
    }

    func reload(
        context: ModelContext,
        restaurantId: UUID?,
        period: AnalyticsPeriod,
        deviceId: UUID?,
        force: Bool = false
    ) {
        loadTask?.cancel()
        rebuildTask?.cancel()
        guard let restaurantId else {
            clear()
            return
        }
        guard reloadPolicy.shouldReload(
            restaurantId: restaurantId,
            hasData: !isEmpty,
            force: force
        ) else { return }

        ensureLoader(container: context.container)

        let showBlockingSpinner = isEmpty
        if showBlockingSpinner {
            isLoading = true
        }

        let haccp = SettingsStorageService.shared.haccp
        loadTask = Task(priority: .utility) { @MainActor in
            defer {
                if !Task.isCancelled {
                    isLoading = false
                }
            }
            await MainThreadYield.afterNavigation()
            guard !Task.isCancelled, let backgroundLoader else { return }
            if force {
                await backgroundLoader.invalidateCache()
            }

            let result = await backgroundLoader.loadPresentation(
                restaurantId: restaurantId,
                period: period,
                deviceId: deviceId,
                force: force,
                haccpSettings: haccp
            )
            guard !Task.isCancelled else { return }

            presentation = result
            dataRevision = UUID()
            reloadPolicy.markLoaded(restaurantId: restaurantId)
        }
    }

    func rebuildPresentation(
        restaurantId: UUID,
        period: AnalyticsPeriod,
        deviceId: UUID?
    ) {
        rebuildTask?.cancel()
        guard backgroundLoader != nil else { return }

        let haccp = SettingsStorageService.shared.haccp
        rebuildTask = Task(priority: .utility) { @MainActor in
            await Task.yield()
            guard !Task.isCancelled, let backgroundLoader else { return }

            let result = await backgroundLoader.loadPresentation(
                restaurantId: restaurantId,
                period: period,
                deviceId: deviceId,
                force: false,
                haccpSettings: haccp
            )
            guard !Task.isCancelled else { return }

            presentation = result
            dataRevision = UUID()
        }
    }

    func clear() {
        reloadPolicy.invalidate()
        presentation = .empty
        isLoading = false
        dataRevision = UUID()
        Task { await backgroundLoader?.invalidateCache() }
    }

    func cancelPendingLoad() {
        loadTask?.cancel()
        loadTask = nil
        rebuildTask?.cancel()
        rebuildTask = nil
    }

    private func ensureLoader(container: ModelContainer) {
        if backgroundLoader == nil {
            backgroundLoader = AnalyticsBackgroundLoader(container: container)
        }
    }

    deinit {
        loadTask?.cancel()
        rebuildTask?.cancel()
    }
}
