//
//  AnalyticsPresentation.swift
//  Dataset grafici pre-calcolati — evita ricalcolo ad ogni frame SwiftUI.
//

import Foundation

struct AnalyticsTemperatureDeviceOption: Identifiable, Hashable {
    let id: UUID
    let name: String
}

struct AnalyticsPresentation {
    var hasAnyData = false

    var checklistPoints: [ChecklistChartPoint] = []
    var checklistKPIs: [AnalyticsKPI] = []

    var temperaturePoints: [TemperatureChartPoint] = []
    var temperatureKPIs: [AnalyticsKPI] = []
    var activeTemperatureDevices: [AnalyticsTemperatureDeviceOption] = []

    var cleaningStackedPoints: [AnalyticsBarSeriesPoint] = []
    var cleaningKPIs: [AnalyticsKPI] = []
    var cleaningIsEmpty = true

    var blastDailyPoints: [AnalyticsDailyPoint] = []
    var blastSlices: [AnalyticsSlicePoint] = []
    var blastKPIs: [AnalyticsKPI] = []
    var blastIsEmpty = true

    var defrostDailyPoints: [AnalyticsDailyPoint] = []
    var defrostSlices: [AnalyticsSlicePoint] = []
    var defrostKPIs: [AnalyticsKPI] = []
    var defrostIsEmpty = true

    var oilPolarPoints: [AnalyticsLinePoint] = []
    var oilStackedPoints: [AnalyticsBarSeriesPoint] = []
    var oilKPIs: [AnalyticsKPI] = []
    var oilIsEmpty = true

    var goodsStackedPoints: [AnalyticsBarSeriesPoint] = []
    var goodsKPIs: [AnalyticsKPI] = []
    var goodsIsEmpty = true

    var traceabilitySlices: [AnalyticsSlicePoint] = []
    var expiryDailyPoints: [AnalyticsDailyPoint] = []
    var traceabilityKPIs: [AnalyticsKPI] = []
    var traceabilityIsEmpty = true

    var labelsDailyPoints: [AnalyticsDailyPoint] = []
    var labelsKPIs: [AnalyticsKPI] = []
    var labelsIsEmpty = true

    static let empty = AnalyticsPresentation()
}
