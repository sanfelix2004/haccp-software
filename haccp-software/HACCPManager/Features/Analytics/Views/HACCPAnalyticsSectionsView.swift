import SwiftUI

/// Grafici per tutti i moduli HACCP operativi.
struct HACCPAnalyticsSectionsView: View {
    let restaurantId: UUID
    @ObservedObject var vm: AnalyticsViewModel

    let checklistRuns: [ChecklistRun]
    let checklistResults: [ChecklistItemResult]
    let checklistAlerts: [ChecklistAlert]
    let temperatureRecords: [TemperatureRecord]
    let temperatureDevices: [TemperatureDevice]
    let cleaningRecords: [CleaningRecord]
    let cleaningCriticalities: [CleaningCriticality]
    let blastRecords: [BlastChillingRecord]
    let defrostRecords: [DefrostRecord]
    let oilRecords: [OilControlRecord]
    let goodsRecords: [GoodsReceivingRecord]
    let traceabilityRecords: [TraceabilityRecord]
    let labelRecords: [ProductionLabelRecord]

    private var hasAnyData: Bool {
        !checklistRuns.filter { $0.restaurantId == restaurantId }.isEmpty
            || !temperatureRecords.filter { $0.restaurantId == restaurantId }.isEmpty
            || !cleaningRecords.filter { $0.restaurantId == restaurantId }.isEmpty
            || !blastRecords.filter { $0.restaurantId == restaurantId }.isEmpty
            || !defrostRecords.filter { $0.restaurantId == restaurantId }.isEmpty
            || !oilRecords.filter { $0.restaurantId == restaurantId }.isEmpty
            || !goodsRecords.filter { $0.restaurantId == restaurantId }.isEmpty
            || !traceabilityRecords.filter { $0.restaurantId == restaurantId }.isEmpty
            || !labelRecords.filter { $0.restaurantId == restaurantId }.isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            if !hasAnyData {
                AnalyticsEmptyStateView(
                    title: "Nessun dato nel periodo",
                    message: "Registra controlli HACCP per popolare i grafici di andamento."
                )
            }

            let checklistPoints = vm.checklistPoints(
                restaurantId: restaurantId,
                runs: checklistRuns,
                itemResults: checklistResults,
                alerts: checklistAlerts
            )

            ChecklistAnalyticsCard(
                points: checklistPoints,
                kpis: vm.checklistKPIs(
                    points: checklistPoints,
                    alerts: checklistAlerts,
                    restaurantId: restaurantId
                )
            )

            let temperaturePoints = vm.temperaturePoints(restaurantId: restaurantId, records: temperatureRecords)

            TemperatureAnalyticsCard(
                points: temperaturePoints,
                kpis: vm.temperatureKPIs(points: temperaturePoints),
                devices: temperatureDevices.filter { $0.restaurantId == restaurantId && $0.isActive }.sorted { $0.name < $1.name },
                selectedDeviceId: $vm.selectedDeviceId,
                selectedPeriod: $vm.selectedPeriod
            )

            AnalyticsModuleSection(
                title: "Controllo pulizia",
                subtitle: "Esiti sanificazione per giorno",
                icon: "sparkles",
                accent: ThemeManager.shared.colorSuccess,
                isEmpty: vm.cleaningStackedPoints(restaurantId: restaurantId, records: cleaningRecords).allSatisfy { $0.value == 0 }
            ) {
                AnalyticsStackedBarChart(points: vm.cleaningStackedPoints(restaurantId: restaurantId, records: cleaningRecords))
                AnalyticsKPIGrid(kpis: vm.cleaningKPIs(records: cleaningRecords, criticalities: cleaningCriticalities, restaurantId: restaurantId))
            }

            AnalyticsModuleSection(
                title: "Abbattimento",
                subtitle: "Cicli completati e conformità",
                icon: "wind.snow",
                accent: ThemeManager.shared.colorInfo,
                isEmpty: vm.blastDailyPoints(restaurantId: restaurantId, records: blastRecords).allSatisfy { $0.value == 0 }
            ) {
                AnalyticsDailyBarChart(
                    points: vm.blastDailyPoints(restaurantId: restaurantId, records: blastRecords),
                    barColor: ThemeManager.shared.colorInfo
                )
                let slices = vm.blastSlices(restaurantId: restaurantId, records: blastRecords)
                if !slices.isEmpty {
                    AnalyticsSectorChart(slices: slices)
                }
                AnalyticsKPIGrid(kpis: vm.blastKPIs(restaurantId: restaurantId, records: blastRecords))
            }

            AnalyticsModuleSection(
                title: "Decongelamento",
                subtitle: "Processi chiusi nel periodo",
                icon: "snowflake",
                accent: ThemeManager.shared.colorInfo,
                isEmpty: vm.defrostDailyPoints(restaurantId: restaurantId, records: defrostRecords).allSatisfy { $0.value == 0 }
            ) {
                AnalyticsDailyBarChart(
                    points: vm.defrostDailyPoints(restaurantId: restaurantId, records: defrostRecords),
                    barColor: .cyan
                )
                let slices = vm.defrostSlices(restaurantId: restaurantId, records: defrostRecords)
                if !slices.isEmpty {
                    AnalyticsSectorChart(slices: slices)
                }
                AnalyticsKPIGrid(kpis: vm.defrostKPIs(restaurantId: restaurantId, records: defrostRecords))
            }

            AnalyticsModuleSection(
                title: "Controllo olio",
                subtitle: "TPM % e stato controlli",
                icon: "drop.fill",
                accent: ThemeManager.shared.colorWarning,
                isEmpty: vm.oilStackedPoints(restaurantId: restaurantId, records: oilRecords).allSatisfy { $0.value == 0 }
            ) {
                let polar = vm.oilPolarPoints(restaurantId: restaurantId, records: oilRecords)
                if !polar.isEmpty {
                    AnalyticsLineChart(points: polar, lineColor: ThemeManager.shared.colorWarning, valueSuffix: "%")
                }
                AnalyticsStackedBarChart(points: vm.oilStackedPoints(restaurantId: restaurantId, records: oilRecords))
                AnalyticsKPIGrid(kpis: vm.oilKPIs(restaurantId: restaurantId, records: oilRecords))
            }

            AnalyticsModuleSection(
                title: "Ricezione merci",
                subtitle: "Conformità giornaliera",
                icon: "shippingbox.fill",
                accent: ThemeManager.shared.colorPrimary,
                isEmpty: vm.goodsStackedPoints(restaurantId: restaurantId, records: goodsRecords).allSatisfy { $0.value == 0 }
            ) {
                AnalyticsStackedBarChart(points: vm.goodsStackedPoints(restaurantId: restaurantId, records: goodsRecords))
                AnalyticsKPIGrid(kpis: vm.goodsKPIs(restaurantId: restaurantId, records: goodsRecords))
            }

            AnalyticsModuleSection(
                title: "Tracciabilità e scadenze",
                subtitle: "Stato prodotti e scadenze imminenti",
                icon: "archivebox.fill",
                accent: ThemeManager.shared.colorSuccess,
                isEmpty: traceabilityRecords.filter({ $0.restaurantId == restaurantId }).isEmpty
            ) {
                let slices = vm.traceabilitySlices(restaurantId: restaurantId, records: traceabilityRecords)
                if !slices.isEmpty {
                    AnalyticsSectorChart(slices: slices, height: 180)
                }
                AnalyticsDailyBarChart(
                    points: vm.expiryDailyPoints(restaurantId: restaurantId, records: traceabilityRecords),
                    barColor: ThemeManager.shared.colorWarning,
                    valueFormat: { String(format: "%.0f", $0) }
                )
                AnalyticsKPIGrid(kpis: vm.traceabilityKPIs(restaurantId: restaurantId, records: traceabilityRecords))
            }

            AnalyticsModuleSection(
                title: "Etichette di produzione",
                subtitle: "Etichette create nel periodo",
                icon: "tag.fill",
                accent: ThemeManager.shared.colorPrimary,
                isEmpty: vm.labelsDailyPoints(restaurantId: restaurantId, labels: labelRecords).allSatisfy { $0.value == 0 }
            ) {
                AnalyticsDailyBarChart(
                    points: vm.labelsDailyPoints(restaurantId: restaurantId, labels: labelRecords),
                    barColor: ThemeManager.shared.colorPrimary
                )
                AnalyticsKPIGrid(kpis: vm.labelsKPIs(restaurantId: restaurantId, labels: labelRecords))
            }
        }
    }
}

private struct AnalyticsModuleSection<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    let isEmpty: Bool
    @ViewBuilder let content: Content

    var body: some View {
        AnalyticsModuleCard(title: title, subtitle: subtitle, icon: icon, accent: accent) {
            if isEmpty {
                AnalyticsEmptyStateView(
                    title: "Nessun dato",
                    message: "Nessuna registrazione nel periodo selezionato."
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
            }
        }
    }
}
