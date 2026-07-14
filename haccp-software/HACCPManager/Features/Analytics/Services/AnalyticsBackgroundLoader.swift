//
//  AnalyticsBackgroundLoader.swift
//  Fetch SwiftData e aggregazione grafici su ModelContext dedicato (non main thread).
//

import Foundation
import SwiftData

actor AnalyticsBackgroundLoader {
    private let container: ModelContainer
    private var cachedData: AnalyticsFetchedData?
    private var cachedRestaurantId: UUID?

    init(container: ModelContainer) {
        self.container = container
    }

    func invalidateCache() {
        cachedData = nil
        cachedRestaurantId = nil
    }

    func loadPresentation(
        restaurantId: UUID,
        period: AnalyticsPeriod,
        deviceId: UUID?,
        force: Bool,
        haccpSettings: HACCPSettings
    ) async -> AnalyticsPresentation {
        if force || cachedRestaurantId != restaurantId || cachedData == nil {
            let context = ModelContext(container)
            context.autosaveEnabled = false
            cachedData = await AnalyticsDataFetcher.fetchAsync(context: context, restaurantId: restaurantId)
            cachedRestaurantId = restaurantId
        }

        guard let data = cachedData else { return .empty }

        return await AnalyticsPresentationBuilder.buildAsync(
            data: data,
            restaurantId: restaurantId,
            period: period,
            deviceId: deviceId,
            haccpSettings: haccpSettings
        )
    }
}
