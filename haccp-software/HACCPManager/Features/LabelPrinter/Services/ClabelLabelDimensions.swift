import Foundation

/// Etichetta 50×30 mm @ 203 DPI (famiglia CLABEL / Chiteng).
enum ClabelLabelDimensions {
    static let dpi = 203
    static let widthMM = 50
    static let heightMM = 30

    static let widthDots = Int((Double(widthMM) / 25.4 * Double(dpi)).rounded())
    static let heightDots = Int((Double(heightMM) / 25.4 * Double(dpi)).rounded())
    static let widthBytes = (widthDots + 7) / 8

    /// Alias per renderer bitmap.
    static let printHeadWidthDots = widthDots
}

enum ClabelPrintEngine: String, Codable, CaseIterable, Identifiable {
    case auto
    case tsplBitmap
    case tsplText
    case escPosLujiang
    case escPosAiYin

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Automatico"
        case .tsplBitmap: return "TSPL (immagine)"
        case .tsplText: return "TSPL (testo)"
        case .escPosLujiang: return "ESC/POS A"
        case .escPosAiYin: return "ESC/POS B"
        }
    }
}
