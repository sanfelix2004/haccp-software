//
//  LabelStickerCanvas.swift
//  Anteprima adesivo 50×30 mm — testo sempre dentro il riquadro.
//

import SwiftUI

struct LabelStickerContent: Equatable {
    var productName: String
    var detailLines: [String]
    var qrPayload: String
    var sourceModuleLabel: String?

    static func from(_ label: ProductionLabelRecord, settings: LabelPrinterSettings) -> LabelStickerContent {
        let profile = settings.labelSpec.layout
        let allLines = ProductionLabelPrintContent.printLines(for: label, settings: settings)
        let detailLines = allLines
            .filter { $0.id != "brand" && $0.id != "product" }
            .map(\.text)
            .prefix(profile.maxDetailLines)

        let productLine = allLines.first(where: { $0.id == "product" })?.text ?? label.productName

        return LabelStickerContent(
            productName: productLine,
            detailLines: Array(detailLines),
            qrPayload: LabelQRCodeLayout.payload(for: label),
            sourceModuleLabel: label.sourceModule.displayLabel
        )
    }
}

enum LabelStickerText {
    /// Anteprima UI — può usare ellissi tipografica.
    static func fit(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        return String(trimmed.prefix(max(1, maxLength - 1))) + "…"
    }

    /// Stampa termica TSPL/CODEPAGE 1252 — solo ASCII, senza ellissi Unicode.
    static func printerFit(_ text: String, maxLength: Int) -> String {
        let cleaned = ProductionLabelPrintContent.printerSafe(text)
        guard cleaned.count > maxLength else { return cleaned }
        return String(cleaned.prefix(maxLength))
    }
}

struct LabelStickerCanvas: View {
    let content: LabelStickerContent
    var showSizeCaption: Bool = true
    var maxPreviewWidth: CGFloat = 420

    @Environment(\.theme) private var theme
    @Bindable private var settingsStorage = SettingsStorageService.shared
    @State private var qrImage: UIImage?
    @State private var qrLoadFailed = false

    private var settings: LabelPrinterSettings { settingsStorage.printer }

    private var labelSpec: ClabelLabelSpec { settings.labelSpec }

    private var aspectRatio: CGFloat {
        CGFloat(labelSpec.widthMM) / CGFloat(labelSpec.heightMM)
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let width = min(geo.size.width, maxPreviewWidth)
                let height = width / aspectRatio
                stickerSurface(width: width, height: height)
                    .frame(width: width, height: height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .frame(maxWidth: maxPreviewWidth)
            .frame(maxWidth: .infinity)

            if showSizeCaption {
                Text("\(labelSpec.widthMM)×\(labelSpec.heightMM) mm · CLABEL S1")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.colorTextSecondary)
            }
        }
        .task(id: qrTaskID) {
            await loadQR()
        }
    }

    @ViewBuilder
    private func stickerSurface(width: CGFloat, height: CGFloat) -> some View {
        let padding = max(8, height * 0.08)
        let qrSide = qrSideLength(labelHeight: height, labelWidth: width)
        let spacing = max(6, height * 0.04)
        let textWidth = max(40, width - padding * 2 - (qrSide > 0 ? qrSide + spacing : 0))

        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white)

            HStack(alignment: .top, spacing: spacing) {
                stickerTextColumn(width: textWidth, height: height - padding * 2)
                    .frame(width: textWidth, alignment: .leading)

                if settings.showQRCode, qrSide > 0 {
                    qrBlock(side: qrSide)
                        .frame(width: qrSide, height: qrSide, alignment: .top)
                }
            }
            .padding(padding)
            .frame(width: width, height: height, alignment: .topLeading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(theme.colorDivider.opacity(0.9))
        )
    }

    @ViewBuilder
    private func stickerTextColumn(width: CGFloat, height: CGFloat) -> some View {
        ViewThatFits(in: .vertical) {
            textStack(density: .regular, width: width)
            textStack(density: .compact, width: width)
            textStack(density: .minimal, width: width)
        }
        .frame(maxWidth: width, maxHeight: height, alignment: .topLeading)
        .clipped()
    }

    private enum TextDensity {
        case regular, compact, minimal

        var headerSize: CGFloat {
            switch self {
            case .regular: return 8
            case .compact: return 7
            case .minimal: return 6
            }
        }

        var titleSize: CGFloat {
            switch self {
            case .regular: return 13
            case .compact: return 11
            case .minimal: return 10
            }
        }

        var lineSize: CGFloat {
            switch self {
            case .regular: return 10
            case .compact: return 9
            case .minimal: return 8
            }
        }

        var spacing: CGFloat {
            switch self {
            case .regular: return 4
            case .compact: return 3
            case .minimal: return 2
            }
        }

        var maxDetailLines: Int {
            switch self {
            case .regular: return 5
            case .compact: return 4
            case .minimal: return 4
            }
        }
    }

    private func maxDetailLines(for density: TextDensity) -> Int {
        min(density.maxDetailLines, settings.labelSpec.layout.maxDetailLines)
    }

    @ViewBuilder
    private func textStack(density: TextDensity, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: density.spacing) {
            if settings.showProductName {
                Text(content.productName)
                    .font(.system(size: density.titleSize, weight: .bold))
                    .foregroundStyle(.black)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(content.detailLines.prefix(maxDetailLines(for: density)).enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: density.lineSize, weight: .regular))
                    .foregroundStyle(.black.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .frame(maxWidth: width, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func qrBlock(side: CGFloat) -> some View {
        ZStack {
            Color.white
            if let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(1)
            } else if qrLoadFailed {
                Image(systemName: "qrcode")
                    .font(.system(size: side * 0.35))
                    .foregroundStyle(.gray)
            } else {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
        )
    }

    private func qrSideLength(labelHeight: CGFloat, labelWidth: CGFloat) -> CGFloat {
        guard settings.showQRCode else { return 0 }
        let heightFactor: CGFloat = 0.46
        let widthFactor: CGFloat = 0.30
        let maxByHeight = labelHeight * heightFactor
        let maxByWidth = labelWidth * widthFactor
        return max(40, min(maxByHeight, maxByWidth))
    }

    private var qrTaskID: String {
        [
            content.qrPayload,
            settings.labelSize,
            String(settings.showQRCode),
            String(settings.qrRotationRaw),
            String(settings.qrCellSize)
        ].joined(separator: "|")
    }

    @MainActor
    private func loadQR() async {
        guard settings.showQRCode else {
            qrImage = nil
            qrLoadFailed = false
            return
        }

        let payload = content.qrPayload
        let cell = LabelQRCodeLayout.clampedCellSize(
            settings.qrCellSize,
            payload: payload,
            settings: settings,
            corner: settings.qrCorner
        )
        let dots = LabelQRCodeLayout.printSizeDots(cellSize: cell, payload: payload, settings: settings)
        let dimension = max(48, CGFloat(dots) * 1.4)
        let rotation = settings.qrRotation

        let image = await Task.detached(priority: .userInitiated) {
            ProductionLabelQRService.image(from: payload, dimension: dimension, rotation: rotation)
        }.value

        qrImage = image
        qrLoadFailed = image == nil
    }
}
