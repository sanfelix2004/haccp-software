import Foundation
import SwiftUI

/// Punto per grafici a barre giornalieri (valore singolo).
struct AnalyticsDailyPoint: Identifiable {
    let id = UUID()
    let dayStart: Date
    let label: String
    let value: Double
}

/// Punto per barre impilate (serie + giorno).
struct AnalyticsBarSeriesPoint: Identifiable {
    let id = UUID()
    let dayLabel: String
    let series: String
    let value: Double
}

/// Punto per grafici a torta / settori.
struct AnalyticsSlicePoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

/// Punto per grafici a linea generici.
struct AnalyticsLinePoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    let isHighlighted: Bool
}

struct AnalyticsDayBucket: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    let label: String
}
