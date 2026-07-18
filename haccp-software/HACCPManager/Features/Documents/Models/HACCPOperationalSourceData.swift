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
    var checklistTemplates: [ChecklistTemplate] = []
    var productionLabels: [ProductionLabelRecord] = []
    var productionIncomingIngredients: [ProductionIncomingIngredient] = []
    var produzioneBatches: [ProduzioneBatch] = []
    var ingredientiTracciati: [IngredienteTracciato] = []
    var lottoProductionLinks: [LottoFotoProductionLink] = []
    var lottoFotos: [LottoFoto] = []
    var productImages: [ProductImage] = []
    var documentMovements: [HACCPDocumentMovement] = []
}
