//
//  AnalyticsPresentationBuilder.swift
//  Aggregazione grafici off-main — ritorna solo value types alla UI.
//

import Foundation

enum AnalyticsPresentationBuilder {

    static func build(
        data: AnalyticsFetchedData,
        restaurantId: UUID,
        period: AnalyticsPeriod,
        deviceId: UUID?,
        haccpSettings: HACCPSettings
    ) -> AnalyticsPresentation {
        let service = AnalyticsService()
        var presentation = AnalyticsPresentation()

        presentation.hasAnyData = !data.checklistRuns.isEmpty
            || !data.temperatureRecords.isEmpty
            || !data.cleaningRecords.isEmpty
            || !data.blastRecords.isEmpty
            || !data.defrostRecords.isEmpty
            || !data.oilRecords.isEmpty
            || !data.goodsRecords.isEmpty
            || !data.traceabilityRecords.isEmpty
            || !data.labelRecords.isEmpty

        let checklistPoints = service.checklistPoints(
            restaurantId: restaurantId,
            runs: data.checklistRuns,
            itemResults: data.checklistResults,
            alerts: data.checklistAlerts,
            period: period
        )
        presentation.checklistPoints = checklistPoints
        presentation.checklistKPIs = service.checklistKPIs(
            points: checklistPoints,
            alerts: data.checklistAlerts,
            restaurantId: restaurantId
        )

        let temperaturePoints = service.temperaturePoints(
            restaurantId: restaurantId,
            records: data.temperatureRecords,
            period: period,
            deviceId: deviceId
        )
        presentation.temperaturePoints = temperaturePoints
        presentation.temperatureKPIs = service.temperatureKPIs(points: temperaturePoints)
        presentation.activeTemperatureDevices = data.temperatureDevices
            .filter(\.isActive)
            .sorted { $0.name < $1.name }
            .map { AnalyticsTemperatureDeviceOption(id: $0.id, name: $0.name) }

        presentation.cleaningStackedPoints = service.cleaningStackedPoints(
            restaurantId: restaurantId,
            records: data.cleaningRecords,
            period: period
        )
        presentation.cleaningKPIs = service.cleaningKPIs(
            records: data.cleaningRecords,
            criticalities: data.cleaningCriticalities,
            restaurantId: restaurantId,
            period: period
        )
        presentation.cleaningIsEmpty = presentation.cleaningStackedPoints.allSatisfy { $0.value == 0 }

        presentation.blastDailyPoints = service.blastChillingDailyPoints(
            restaurantId: restaurantId,
            records: data.blastRecords,
            period: period
        )
        presentation.blastSlices = service.blastChillingSlices(
            records: data.blastRecords,
            restaurantId: restaurantId,
            period: period
        )
        presentation.blastKPIs = service.blastChillingKPIs(
            records: data.blastRecords,
            restaurantId: restaurantId,
            period: period
        )
        presentation.blastIsEmpty = presentation.blastDailyPoints.allSatisfy { $0.value == 0 }

        presentation.defrostDailyPoints = service.defrostDailyPoints(
            restaurantId: restaurantId,
            records: data.defrostRecords,
            period: period
        )
        presentation.defrostSlices = service.defrostSlices(
            records: data.defrostRecords,
            restaurantId: restaurantId,
            period: period
        )
        presentation.defrostKPIs = service.defrostKPIs(
            records: data.defrostRecords,
            restaurantId: restaurantId,
            period: period
        )
        presentation.defrostIsEmpty = presentation.defrostDailyPoints.allSatisfy { $0.value == 0 }

        presentation.oilPolarPoints = service.oilPolarLinePoints(
            restaurantId: restaurantId,
            records: data.oilRecords,
            period: period,
            haccpSettings: haccpSettings
        )
        presentation.oilStackedPoints = service.oilStatusStackedPoints(
            restaurantId: restaurantId,
            records: data.oilRecords,
            period: period
        )
        presentation.oilKPIs = service.oilKPIs(
            records: data.oilRecords,
            restaurantId: restaurantId,
            period: period
        )
        presentation.oilIsEmpty = presentation.oilStackedPoints.allSatisfy { $0.value == 0 }

        presentation.goodsStackedPoints = service.goodsReceivingStackedPoints(
            restaurantId: restaurantId,
            records: data.goodsRecords,
            period: period
        )
        presentation.goodsKPIs = service.goodsReceivingKPIs(
            records: data.goodsRecords,
            restaurantId: restaurantId,
            period: period
        )
        presentation.goodsIsEmpty = presentation.goodsStackedPoints.allSatisfy { $0.value == 0 }

        presentation.traceabilitySlices = service.traceabilityStatusSlices(
            records: data.traceabilityRecords,
            restaurantId: restaurantId
        )
        presentation.expiryDailyPoints = service.expiryUpcomingDailyPoints(
            records: data.traceabilityRecords,
            restaurantId: restaurantId
        )
        presentation.traceabilityKPIs = service.traceabilityKPIs(
            records: data.traceabilityRecords,
            restaurantId: restaurantId,
            haccpSettings: haccpSettings
        )
        presentation.traceabilityIsEmpty = data.traceabilityRecords.isEmpty

        presentation.labelsDailyPoints = service.labelsDailyPoints(
            restaurantId: restaurantId,
            labels: data.labelRecords,
            period: period
        )
        presentation.labelsKPIs = service.labelsKPIs(
            labels: data.labelRecords,
            restaurantId: restaurantId,
            period: period
        )
        presentation.labelsIsEmpty = presentation.labelsDailyPoints.allSatisfy { $0.value == 0 }

        return presentation
    }

    static func buildAsync(
        data: AnalyticsFetchedData,
        restaurantId: UUID,
        period: AnalyticsPeriod,
        deviceId: UUID?,
        haccpSettings: HACCPSettings
    ) async -> AnalyticsPresentation {
        await Task.yield()
        return build(
            data: data,
            restaurantId: restaurantId,
            period: period,
            deviceId: deviceId,
            haccpSettings: haccpSettings
        )
    }
}
