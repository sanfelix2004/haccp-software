import Foundation

/// Rotoli termici CLABEL S1 (kit congelatore / cucina).
enum ClabelLabelSize: String, Codable, CaseIterable, Identifiable {
    case mm40x30 = "40x30"
    case mm50x30 = "50x30"

    var id: String { rawValue }

    var widthMM: Int {
        switch self {
        case .mm40x30: return 40
        case .mm50x30: return 50
        }
    }

    static let heightMM = 30

    var displayName: String {
        switch self {
        case .mm40x30: return "40×30 mm"
        case .mm50x30: return "50×30 mm"
        }
    }

    var usageHint: String {
        switch self {
        case .mm40x30: return "Rotoli compatti — congelatore e porzioni"
        case .mm50x30: return "Rotolo standard — più spazio per testo e QR"
        }
    }

    static func parse(_ value: String) -> ClabelLabelSize? {
        if let exact = ClabelLabelSize(rawValue: value) { return exact }
        let normalized = value.lowercased().replacingOccurrences(of: " ", with: "")
        if normalized.contains("40") && normalized.contains("30") { return .mm40x30 }
        if normalized.contains("50") && normalized.contains("30") { return .mm50x30 }
        return nil
    }
}

/// Profilo tipografico e QR per far entrare tutti i campi nell'adesivo.
struct ClabelLabelLayoutProfile {
    let brandFontSize: CGFloat
    let productFontSize: CGFloat
    let detailFontSize: CGFloat
    let smallFontSize: CGFloat
    let contentPadding: CGFloat
    let lineGap: CGFloat

    let tsplProductFont: String
    let tsplDetailFont: String
    let tsplProductYStep: Int
    let tsplDetailYStep: Int
    let tsplTextX: Int

    let preferredQRCell: Int
    let minQRCell: Int
    let minPrintDots: Int
    let qrMarginDots: Int
    let maxDetailLines: Int
    let productNameMaxLength: Int
    let detailMaxLength: Int
}

struct ClabelLabelSpec: Equatable {
    let size: ClabelLabelSize
    let dpi: Int
    let gapMM: Int

    init(size: ClabelLabelSize, dpi: Int = 203, gapMM: Int = 3) {
        self.size = size
        self.dpi = dpi
        self.gapMM = gapMM
    }

    var widthMM: Int { size.widthMM }
    var heightMM: Int { ClabelLabelSize.heightMM }
    var widthDots: Int { dots(forMM: widthMM) }
    var heightDots: Int { dots(forMM: heightMM) }
    var widthBytes: Int { (widthDots + 7) / 8 }
    var layout: ClabelLabelLayoutProfile { size.layoutProfile }

    private func dots(forMM mm: Int) -> Int {
        Int((Double(mm) / 25.4 * Double(dpi)).rounded())
    }
}

extension ClabelLabelSize {
    var layoutProfile: ClabelLabelLayoutProfile {
        switch self {
        case .mm40x30:
            return ClabelLabelLayoutProfile(
                brandFontSize: 7,
                productFontSize: 11,
                detailFontSize: 8,
                smallFontSize: 7,
                contentPadding: 5,
                lineGap: 1,
                tsplProductFont: "2",
                tsplDetailFont: "1",
                tsplProductYStep: 26,
                tsplDetailYStep: 19,
                tsplTextX: 8,
                preferredQRCell: 3,
                minQRCell: 2,
                minPrintDots: 80,
                qrMarginDots: 5,
                maxDetailLines: 7,
                productNameMaxLength: 22,
                detailMaxLength: 24
            )
        case .mm50x30:
            return ClabelLabelLayoutProfile(
                brandFontSize: 9,
                productFontSize: 14,
                detailFontSize: 10,
                smallFontSize: 8,
                contentPadding: 8,
                lineGap: 2,
                tsplProductFont: "3",
                tsplDetailFont: "1",
                tsplProductYStep: 34,
                tsplDetailYStep: 23,
                tsplTextX: 10,
                preferredQRCell: 4,
                minQRCell: 3,
                minPrintDots: 96,
                qrMarginDots: 8,
                maxDetailLines: 10,
                productNameMaxLength: 28,
                detailMaxLength: 32
            )
        }
    }
}

/// Accesso dimensioni — preferire `LabelPrinterSettings.labelSpec`.
enum ClabelLabelDimensions {
    static let dpi = 203
    static let defaultSize = ClabelLabelSize.mm50x30

    static var defaultSpec: ClabelLabelSpec { ClabelLabelSpec(size: defaultSize) }

    static var widthMM: Int { defaultSpec.widthMM }
    static var heightMM: Int { defaultSpec.heightMM }
    static var widthDots: Int { defaultSpec.widthDots }
    static var heightDots: Int { defaultSpec.heightDots }
    static var widthBytes: Int { defaultSpec.widthBytes }
    static var printHeadWidthDots: Int { widthDots }
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
