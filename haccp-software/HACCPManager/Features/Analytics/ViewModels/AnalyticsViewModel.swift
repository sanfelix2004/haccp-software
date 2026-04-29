import Foundation

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var selectedPeriod: AnalyticsPeriod = .sevenDays
    @Published var selectedDeviceId: UUID?

    private let service = AnalyticsService()

    func checklistPoints(
        restaurantId: UUID,
        runs: [ChecklistRun],
        itemResults: [ChecklistItemResult],
        alerts: [ChecklistAlert]
    ) -> [ChecklistChartPoint] {
        service.checklistWeeklyPoints(
            restaurantId: restaurantId,
            runs: runs,
            itemResults: itemResults,
            alerts: alerts
        )
    }

    func checklistKPIs(
        points: [ChecklistChartPoint],
        alerts: [ChecklistAlert],
        restaurantId: UUID
    ) -> [AnalyticsKPI] {
        service.checklistKPIs(points: points, alerts: alerts, restaurantId: restaurantId)
    }

    func temperaturePoints(
        restaurantId: UUID,
        records: [TemperatureRecord]
    ) -> [TemperatureChartPoint] {
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
}
