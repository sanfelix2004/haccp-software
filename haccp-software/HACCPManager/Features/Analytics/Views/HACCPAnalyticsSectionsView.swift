import SwiftUI

/// Grafici per tutti i moduli HACCP operativi — dataset pre-calcolati, sezioni lazy.
struct HACCPAnalyticsSectionsView: View {
    let presentation: AnalyticsPresentation
    @ObservedObject var vm: AnalyticsViewModel

    var body: some View {
        LazyVStack(spacing: 16) {
            if !presentation.hasAnyData {
                AnalyticsEmptyStateView(
                    title: "Nessun dato nel periodo",
                    message: "Registra controlli HACCP per popolare i grafici di andamento."
                )
            }

            ChecklistAnalyticsCard(
                points: presentation.checklistPoints,
                kpis: presentation.checklistKPIs
            )

            TemperatureAnalyticsCard(
                points: presentation.temperaturePoints,
                kpis: presentation.temperatureKPIs,
                devices: presentation.activeTemperatureDevices,
                selectedDeviceId: $vm.selectedDeviceId
            )

            AnalyticsModuleSection(
                title: "Controllo pulizia",
                subtitle: "Esiti sanificazione per giorno",
                icon: "sparkles",
                accent: ThemeManager.shared.colorSuccess,
                isEmpty: presentation.cleaningIsEmpty
            ) {
                AnalyticsStackedBarChart(points: presentation.cleaningStackedPoints)
                AnalyticsKPIGrid(kpis: presentation.cleaningKPIs)
            }

            AnalyticsModuleSection(
                title: "Abbattimento",
                subtitle: "Cicli completati e conformità",
                icon: "wind.snow",
                accent: ThemeManager.shared.colorInfo,
                isEmpty: presentation.blastIsEmpty
            ) {
                AnalyticsDailyBarChart(
                    points: presentation.blastDailyPoints,
                    barColor: ThemeManager.shared.colorInfo
                )
                if !presentation.blastSlices.isEmpty {
                    AnalyticsSectorChart(slices: presentation.blastSlices)
                }
                AnalyticsKPIGrid(kpis: presentation.blastKPIs)
            }

            AnalyticsModuleSection(
                title: "Decongelamento",
                subtitle: "Processi chiusi nel periodo",
                icon: "snowflake",
                accent: ThemeManager.shared.colorInfo,
                isEmpty: presentation.defrostIsEmpty
            ) {
                AnalyticsDailyBarChart(
                    points: presentation.defrostDailyPoints,
                    barColor: .cyan
                )
                if !presentation.defrostSlices.isEmpty {
                    AnalyticsSectorChart(slices: presentation.defrostSlices)
                }
                AnalyticsKPIGrid(kpis: presentation.defrostKPIs)
            }

            AnalyticsModuleSection(
                title: "Controllo olio",
                subtitle: "TPM % e stato controlli",
                icon: "drop.fill",
                accent: ThemeManager.shared.colorWarning,
                isEmpty: presentation.oilIsEmpty
            ) {
                if !presentation.oilPolarPoints.isEmpty {
                    AnalyticsLineChart(
                        points: presentation.oilPolarPoints,
                        lineColor: ThemeManager.shared.colorWarning,
                        valueSuffix: "%"
                    )
                }
                AnalyticsStackedBarChart(points: presentation.oilStackedPoints)
                AnalyticsKPIGrid(kpis: presentation.oilKPIs)
            }

            AnalyticsModuleSection(
                title: "Ricezione merci",
                subtitle: "Conformità giornaliera",
                icon: "shippingbox.fill",
                accent: ThemeManager.shared.colorPrimary,
                isEmpty: presentation.goodsIsEmpty
            ) {
                AnalyticsStackedBarChart(points: presentation.goodsStackedPoints)
                AnalyticsKPIGrid(kpis: presentation.goodsKPIs)
            }

            AnalyticsModuleSection(
                title: "Tracciabilità e scadenze",
                subtitle: "Stato prodotti e scadenze imminenti",
                icon: "archivebox.fill",
                accent: ThemeManager.shared.colorSuccess,
                isEmpty: presentation.traceabilityIsEmpty
            ) {
                if !presentation.traceabilitySlices.isEmpty {
                    AnalyticsSectorChart(slices: presentation.traceabilitySlices, height: 180)
                }
                AnalyticsDailyBarChart(
                    points: presentation.expiryDailyPoints,
                    barColor: ThemeManager.shared.colorWarning,
                    valueFormat: { String(format: "%.0f", $0) }
                )
                AnalyticsKPIGrid(kpis: presentation.traceabilityKPIs)
            }

            AnalyticsModuleSection(
                title: "Etichette di produzione",
                subtitle: "Etichette create nel periodo",
                icon: "tag.fill",
                accent: ThemeManager.shared.colorPrimary,
                isEmpty: presentation.labelsIsEmpty
            ) {
                AnalyticsDailyBarChart(
                    points: presentation.labelsDailyPoints,
                    barColor: ThemeManager.shared.colorPrimary
                )
                AnalyticsKPIGrid(kpis: presentation.labelsKPIs)
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
