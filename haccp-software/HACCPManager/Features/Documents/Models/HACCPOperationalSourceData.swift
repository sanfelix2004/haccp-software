import Foundation

/// Dati operativi per registri singoli (temperature, pulizia, processi, checklist, olio, etichette).
struct HACCPOperationalSourceData {
    var temperatureRecords: [TemperatureRecord] = []
    var cleaningRecords: [CleaningRecord] = []
    var defrostRecords: [DefrostRecord] = []
    var blastChillingRecords: [BlastChillingRecord] = []
    var oilControlRecords: [OilControlRecord] = []
    var checklistRuns: [ChecklistRun] = []
    var checklistItemResults: [ChecklistItemResult] = []
    var productionLabels: [ProductionLabelRecord] = []
}
