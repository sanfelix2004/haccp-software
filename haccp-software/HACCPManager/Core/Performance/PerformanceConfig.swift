//
//  PerformanceConfig.swift
//  HACCP Manager — Limiti centralizzati per RAM/CPU.
//

import Foundation

enum PerformanceConfig {
    /// Record massimi per tipo nello storico (ultimi N per ristorante).
    static let historyFetchLimitPerType = 400

    /// Registrazioni mostrate per pagina nel dettaglio modulo.
    static let historyPageSize = 50

    /// Badge dashboard: campione per conteggi (evita scan completo).
    static let dashboardSampleLimit = 500

    /// Ritardo minimo tra refresh archivio PDF automatici (secondi).
    static let documentsAutoArchiveInterval: TimeInterval = 600

    /// Lato lungo massimo immagini salvate in UI (px).
    static let imageMaxPixelDimension: CGFloat = 1024

    /// Decodifica sorgente ad alta risoluzione prima del ritaglio area stampa.
    static let groqVisionDecodeMaxPixel: CGFloat = 1536

    /// Lato lungo inviato a Groq dopo ritaglio/enhance.
    static let groqVisionMaxPixel: CGFloat = 1280

    /// Qualità JPEG Groq — massimo dettaglio per caratteri a matrice.
    static let groqVisionJPEGQuality: CGFloat = 0.92

    /// Anteprima in memoria durante acquisizione (px).
    static let capturePreviewMaxPixelDimension: CGFloat = 1280

    /// Qualità JPEG per allegati/compressione.
    static let imageJPEGQuality: CGFloat = 0.82

    /// Debounce filtri storico (ms).
    static let filterDebounceNanoseconds: UInt64 = 200_000_000

    /// Dati operativi più recenti di N mesi restano attivi; oltre → archivio.
    static let activeDataRetentionMonths = 12

    /// Record archiviati per ciclo (evita spike CPU).
    static let archiveBatchSize = 80

    /// Minimo intervallo tra cicli archivio automatico (secondi).
    static let archiveRunInterval: TimeInterval = 86_400

    /// Thumbnail per foto archiviate (px).
    static let archiveThumbnailMaxPixel: CGFloat = 512

    /// Qualità JPEG foto archiviate.
    static let archiveJPEGQuality: CGFloat = 0.72

    /// Limite record tracciabilità in schermata operativa.
    static let traceabilityActiveFetchLimit = 600

    /// Run checklist attive per ristorante (tab Oggi / Storico).
    static let checklistRunFetchLimit = 350

    /// Modelli checklist per ristorante.
    static let checklistTemplateFetchLimit = 150

    /// Risultati voci checklist (ultimi run caricati).
    static let checklistItemResultFetchLimit = 2_500

    /// Alert checklist attivi.
    static let checklistAlertFetchLimit = 200

    /// Criticità pulizia collegate al tab Criticità.
    static let checklistCleaningCriticalityFetchLimit = 150

    /// Giorni massimi caricati per serie temporali grafici (allineato a 30 giorni).
    static let analyticsLookbackDays = 30

    /// Record per tipo nelle serie analytics (temperature, pulizie, olio, ecc.).
    static let analyticsSeriesFetchLimit = 500

    /// Snapshot tracciabilità attiva per KPI/scadenze nei grafici.
    static let analyticsTraceabilitySnapshotLimit = 600

    /// PDF e metadati archivio documenti per ristorante.
    static let documentsItemFetchLimit = 2_000

    /// Cartelle archivio (albero venue/moduli).
    static let documentsFolderFetchLimit = 400

    /// Record massimi per export CSV on-demand (per periodo documento).
    static let documentsCSVExportFetchLimit = 500

    /// Durata consigliata abbattimento (minuti) prima del warning overlay.
    static let blastChillingRecommendedMinutes: Int = 90

    /// Fine prevista decongelamento per metodo (ore) — base HACCP cucina professionale.
    static let defrostFridgeRecommendedHours: Int = 24
    static let defrostControlledTempRecommendedHours: Int = 12
    static let defrostColdWaterRecommendedHours: Int = 4
    static let defrostMicrowaveRecommendedHours: Int = 2
    static let defrostOtherRecommendedHours: Int = 24
}
