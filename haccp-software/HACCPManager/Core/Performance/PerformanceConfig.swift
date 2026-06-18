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

    /// Durata consigliata abbattimento (minuti) prima del warning overlay.
    static let blastChillingRecommendedMinutes: Int = 90

    /// Fine prevista decongelamento per metodo (ore) — base HACCP cucina professionale.
    static let defrostFridgeRecommendedHours: Int = 24
    static let defrostControlledTempRecommendedHours: Int = 12
    static let defrostColdWaterRecommendedHours: Int = 4
    static let defrostMicrowaveRecommendedHours: Int = 2
    static let defrostOtherRecommendedHours: Int = 24
}
