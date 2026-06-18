import Foundation
import Combine

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var selectedPeriod: AnalyticsPeriod = .sevenDays
    @Published var selectedDeviceId: UUID?

    private let service = AnalyticsService()

    // Checklist
    func checklistPoints(
        restaurantId: UUID,
        runs: [ChecklistRun],
        itemResults: [ChecklistItemResult],
        alerts: [ChecklistAlert]
    ) -> [ChecklistChartPoint] {
        service.checklistPoints(
            restaurantId: restaurantId,
            runs: runs,
            itemResults: itemResults,
            alerts: alerts,
            period: selectedPeriod
        )
    }

    func checklistKPIs(
        points: [ChecklistChartPoint],
        alerts: [ChecklistAlert],
        restaurantId: UUID
    ) -> [AnalyticsKPI] {
        service.checklistKPIs(points: points, alerts: alerts, restaurantId: restaurantId)
    }

    // Temperature
    func temperaturePoints(restaurantId: UUID, records: [TemperatureRecord]) -> [TemperatureChartPoint] {
        service.temperaturePoints(
            restaurantId: restaurantId,
            records: records,
            period: selectedPeriod,
            deviceId: selectedDeviceId
        )
    }

    func temperatureKPIs(points: [TemperatureChartPoint]) -> [AnalyticsKPI] {
        service.temperatureKPIs(points: points)
    }

    // Cleaning
    func cleaningStackedPoints(restaurantId: UUID, records: [CleaningRecord]) -> [AnalyticsBarSeriesPoint] {
        service.cleaningStackedPoints(restaurantId: restaurantId, records: records, period: selectedPeriod)
    }

    func cleaningKPIs(
        records: [CleaningRecord],
        criticalities: [CleaningCriticality],
        restaurantId: UUID
    ) -> [AnalyticsKPI] {
        service.cleaningKPIs(
            records: records,
            criticalities: criticalities,
            restaurantId: restaurantId,
            period: selectedPeriod
        )
    }

    // Blast chilling
    func blastDailyPoints(restaurantId: UUID, records: [BlastChillingRecord]) -> [AnalyticsDailyPoint] {
        service.blastChillingDailyPoints(restaurantId: restaurantId, records: records, period: selectedPeriod)
    }

    func blastSlices(restaurantId: UUID, records: [BlastChillingRecord]) -> [AnalyticsSlicePoint] {
        service.blastChillingSlices(records: records, restaurantId: restaurantId, period: selectedPeriod)
    }

    func blastKPIs(restaurantId: UUID, records: [BlastChillingRecord]) -> [AnalyticsKPI] {
        service.blastChillingKPIs(records: records, restaurantId: restaurantId, period: selectedPeriod)
    }

    // Defrost
    func defrostDailyPoints(restaurantId: UUID, records: [DefrostRecord]) -> [AnalyticsDailyPoint] {
        service.defrostDailyPoints(restaurantId: restaurantId, records: records, period: selectedPeriod)
    }

    func defrostSlices(restaurantId: UUID, records: [DefrostRecord]) -> [AnalyticsSlicePoint] {
        service.defrostSlices(records: records, restaurantId: restaurantId, period: selectedPeriod)
    }

    func defrostKPIs(restaurantId: UUID, records: [DefrostRecord]) -> [AnalyticsKPI] {
        service.defrostKPIs(records: records, restaurantId: restaurantId, period: selectedPeriod)
    }

    // Oil
    func oilPolarPoints(restaurantId: UUID, records: [OilControlRecord]) -> [AnalyticsLinePoint] {
        service.oilPolarLinePoints(restaurantId: restaurantId, records: records, period: selectedPeriod)
    }

    func oilStackedPoints(restaurantId: UUID, records: [OilControlRecord]) -> [AnalyticsBarSeriesPoint] {
        service.oilStatusStackedPoints(restaurantId: restaurantId, records: records, period: selectedPeriod)
    }

    func oilKPIs(restaurantId: UUID, records: [OilControlRecord]) -> [AnalyticsKPI] {
        service.oilKPIs(records: records, restaurantId: restaurantId, period: selectedPeriod)
    }

    // Goods receiving
    func goodsStackedPoints(restaurantId: UUID, records: [GoodsReceivingRecord]) -> [AnalyticsBarSeriesPoint] {
        service.goodsReceivingStackedPoints(restaurantId: restaurantId, records: records, period: selectedPeriod)
    }

    func goodsKPIs(restaurantId: UUID, records: [GoodsReceivingRecord]) -> [AnalyticsKPI] {
        service.goodsReceivingKPIs(records: records, restaurantId: restaurantId, period: selectedPeriod)
    }

    // Traceability
    func traceabilitySlices(restaurantId: UUID, records: [TraceabilityRecord]) -> [AnalyticsSlicePoint] {
        service.traceabilityStatusSlices(records: records, restaurantId: restaurantId)
    }

    func expiryDailyPoints(restaurantId: UUID, records: [TraceabilityRecord]) -> [AnalyticsDailyPoint] {
        service.expiryUpcomingDailyPoints(records: records, restaurantId: restaurantId)
    }

    func traceabilityKPIs(restaurantId: UUID, records: [TraceabilityRecord]) -> [AnalyticsKPI] {
        service.traceabilityKPIs(records: records, restaurantId: restaurantId)
    }

    // Labels
    func labelsDailyPoints(restaurantId: UUID, labels: [ProductionLabelRecord]) -> [AnalyticsDailyPoint] {
        service.labelsDailyPoints(restaurantId: restaurantId, labels: labels, period: selectedPeriod)
    }

    func labelsKPIs(restaurantId: UUID, labels: [ProductionLabelRecord]) -> [AnalyticsKPI] {
        service.labelsKPIs(labels: labels, restaurantId: restaurantId, period: selectedPeriod)
    }

    // Scheduling
    func schedulingStackedPoints(restaurantId: UUID, tasks: [ScheduledTask]) -> [AnalyticsBarSeriesPoint] {
        service.schedulingStackedPoints(restaurantId: restaurantId, tasks: tasks, period: selectedPeriod)
    }

    func schedulingKPIs(restaurantId: UUID, tasks: [ScheduledTask]) -> [AnalyticsKPI] {
        service.schedulingKPIs(tasks: tasks, restaurantId: restaurantId)
    }
}
