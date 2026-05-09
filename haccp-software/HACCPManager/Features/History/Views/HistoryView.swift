import SwiftUI
import SwiftData

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @Query private var temperatureRecords: [TemperatureRecord]
    @Query private var fridgeRecords: [FridgeCheckRecord]
    @Query private var checklistRuns: [ChecklistRun]
    @Query private var checklistItemResults: [ChecklistItemResult]
    @Query private var checklistAuditLogs: [ChecklistAuditLog]
    @Query private var cleaningRecords: [CleaningRecord]
    @Query private var defrostRecords: [DefrostRecord]
    @Query private var blastRecords: [BlastChillingRecord]
    @Query private var labelRecords: [ProductionLabelRecord]
    @Query private var goodsRecords: [GoodsReceipt]
    @Query private var traceabilityRecords: [TraceabilityRecord]
    @Query private var traceabilityLogs: [TraceabilityLog]
    @Query private var scheduledTasks: [ScheduledTask]
    @Query private var oilRecords: [OilControlRecord]

    @StateObject private var vm = HistoryViewModel()

    private var allEntries: [HistoryEntry] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return vm.service.buildEntries(
            restaurantId: rid,
            temperatureRecords: temperatureRecords,
            fridgeRecords: fridgeRecords,
            checklistRuns: checklistRuns,
            checklistItemResults: checklistItemResults,
            checklistAuditLogs: checklistAuditLogs,
            cleaningRecords: cleaningRecords,
            defrostRecords: defrostRecords,
            blastRecords: blastRecords,
            labelRecords: labelRecords,
            goodsRecords: goodsRecords,
            traceabilityRecords: traceabilityRecords,
            traceabilityLogs: traceabilityLogs,
            scheduledTasks: scheduledTasks,
            oilRecords: oilRecords
        )
    }

    var body: some View {
        HistoryDashboardView(entries: allEntries)
    }
}
