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
        var lines: [String] = []

        if settings.showLotNumber, let lot = label.lotCode?.trimmingCharacters(in: .whitespacesAndNewlines), !lot.isEmpty {
            lines.append("Lotto \(LabelStickerText.fit(lot, maxLength: 28))")
        }
        if settings.showPrepDate {
            lines.append("Prod. \(label.productionDate.formatted(date: .abbreviated, time: .omitted))")
        }
        if settings.showExpiryDate {
            lines.append("Scad. \(label.expiryDate.formatted(date: .abbreviated, time: .omitted))")
        }
        if settings.showOperatorName {
            lines.append("Op. \(LabelStickerText.fit(label.createdByNameSnapshot, maxLength: 22))")
        }
        if let supplier = label.supplier?.trimmingCharacters(in: .whitespacesAndNewlines), !supplier.isEmpty {
            lines.append(LabelStickerText.fit(supplier, maxLength: 32))
        }
        if let qty = label.quantityDisplay {
            lines.append(LabelStickerText.fit(qty, maxLength: 24))
        }
        if let temp = label.temperatureNote?.trimmingCharacters(in: .whitespacesAndNewlines), !temp.isEmpty {
            lines.append(LabelStickerText.fit(temp, maxLength: 28))
        }
        if settings.showAllergenWarning, !label.allergenList.isEmpty {
            let allergenText = label.allergenList.prefix(4).joined(separator: ", ")
            lines.append("All: \(LabelStickerText.fit(allergenText, maxLength: 36))")
        }
        if let storage = label.storageInstructions?.trimmingCharacters(in: .whitespacesAndNewlines), !storage.isEmpty {
            lines.append(LabelStickerText.fit(storage, maxLength: 36))
        }

        return LabelStickerContent(
            productName: label.productName,
            detailLines: lines,
            qrPayload: LabelQRCodeLayout.payload(for: label),
            sourceModuleLabel: label.sourceModule.displayLabel
        )
    }
}

enum LabelStickerText {
    static func fit(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        return String(trimmed.prefix(max(1, maxLength - 1))) + "…"
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

    private static var aspectRatio: CGFloat {
        CGFloat(ClabelLabelDimensions.widthMM) / CGFloat(ClabelLabelDimensions.heightMM)
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let width = min(geo.size.width, maxPreviewWidth)
                let height = width / Self.aspectRatio
                stickerSurface(width: width, height: height)
                    .frame(width: width, height: height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .aspectRatio(Self.aspectRatio, contentMode: .fit)
            .frame(maxWidth: maxPreviewWidth)
            .frame(maxWidth: .infinity)

            if showSizeCaption {
                Text("\(ClabelLabelDimensions.widthMM)×\(ClabelLabelDimensions.heightMM) mm")
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
        let padding = max(6, height * 0.06)
        let qrSide = qrSideLength(labelHeight: height, labelWidth: width)
        let spacing = max(3, height * 0.025)
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
            case .minimal: return 6.5
            }
        }

        var titleSize: CGFloat {
            switch self {
            case .regular: return 11.5
            case .compact: return 10
            case .minimal: return 9
            }
        }

        var lineSize: CGFloat {
            switch self {
            case .regular: return 8.5
            case .compact: return 7.5
            case .minimal: return 7
            }
        }

        var spacing: CGFloat {
            switch self {
            case .regular: return 2.5
            case .compact: return 1.5
            case .minimal: return 1
            }
        }

        var maxDetailLines: Int {
            switch self {
            case .regular: return 8
            case .compact: return 7
            case .minimal: return 6
            }
        }
    }

    @ViewBuilder
    private func textStack(density: TextDensity, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: density.spacing) {
            Text("HACCP")
                .font(.system(size: density.headerSize, weight: .heavy, design: .rounded))
                .foregroundStyle(.black.opacity(0.55))
                .tracking(0.8)
                .lineLimit(1)

            if settings.showProductName {
                Text(content.productName)
                    .font(.system(size: density.titleSize, weight: .bold))
                    .foregroundStyle(.black)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(content.detailLines.prefix(density.maxDetailLines).enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: density.lineSize, weight: .regular))
                    .foregroundStyle(.black.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .frame(maxWidth: width, alignment: .leading)
            }

            if let source = content.sourceModuleLabel, density != .minimal {
                Text(LabelStickerText.fit(source, maxLength: 18))
                    .font(.system(size: max(6, density.lineSize - 1), weight: .medium))
                    .foregroundStyle(.black.opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
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
        let maxByHeight = labelHeight * 0.46
        let maxByWidth = labelWidth * 0.3
        return max(36, min(maxByHeight, maxByWidth))
    }

    private var qrTaskID: String {
        [
            content.qrPayload,
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
            corner: settings.qrCorner
        )
        let dots = LabelQRCodeLayout.printSizeDots(cellSize: cell, payload: payload)
        let dimension = max(72, CGFloat(dots) * 1.6)
        let rotation = settings.qrRotation

        let image = await Task.detached(priority: .userInitiated) {
            ProductionLabelQRService.image(from: payload, dimension: dimension, rotation: rotation)
        }.value

        qrImage = image
        qrLoadFailed = image == nil
    }
}
