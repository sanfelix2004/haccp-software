//
//  ProductionLabelStickerView.swift
//  Anteprima etichetta adesiva HACCP.
//

import SwiftUI

struct ProductionLabelStickerView: View {
    let label: ProductionLabelRecord
    var compact: Bool = false

    @Environment(\.theme) private var theme
    @Bindable private var settingsStorage = SettingsStorageService.shared
    @State private var qrImage: UIImage?
    @State private var qrLoadFailed = false

    private var printerSettings: LabelPrinterSettings {
        settingsStorage.printer
    }

    private var qrPreviewSide: CGFloat {
        compact ? 56 : 72
    }

    var body: some View {
        HStack(alignment: .top, spacing: compact ? 10 : 14) {
            VStack(alignment: .leading, spacing: compact ? 6 : 8) {
                Text("HACCP")
                    .font(.system(size: compact ? 9 : 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colorPrimary)
                    .tracking(1.2)

                Text(label.productName)
                    .font(compact ? theme.typography.headline : theme.typography.title3)
                    .foregroundStyle(theme.colorTextPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                if let lot = label.lotCode, !lot.isEmpty {
                    labelRow(icon: "barcode", text: "Lotto \(lot)")
                }

                labelRow(
                    icon: "calendar",
                    text: "Prod. \(label.productionDate.formatted(date: .abbreviated, time: .omitted))"
                )
                labelRow(
                    icon: "clock.badge.exclamationmark",
                    text: "Scad. \(label.expiryDate.formatted(date: .abbreviated, time: .omitted))"
                )

                if let supplier = label.supplier, !supplier.isEmpty {
                    labelRow(icon: "building.2", text: supplier)
                }

                if let qty = label.quantityDisplay {
                    labelRow(icon: "scalemass", text: qty)
                }

                if let temp = label.temperatureNote, !temp.isEmpty {
                    labelRow(icon: "thermometer.medium", text: temp)
                }

                if let storage = label.storageInstructions, !storage.isEmpty {
                    labelRow(icon: "snowflake", text: storage)
                }

                labelRow(icon: "person.fill", text: label.createdByNameSnapshot)

                HStack(spacing: 6) {
                    expiryBadge
                    HACCPBadge(title: label.productStatus.label, style: .info, showIcon: false)
                    if !label.allergenList.isEmpty {
                        HACCPBadge(title: "Allergeni", style: .warning, showIcon: true)
                    }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                if printerSettings.showQRCode {
                    Group {
                        if let qrImage {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                        } else if qrLoadFailed {
                            Image(systemName: "qrcode")
                                .font(.title2)
                                .foregroundStyle(theme.colorTextSecondary)
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(width: qrPreviewSide, height: qrPreviewSide)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                Text(label.sourceModule.displayLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.colorTextSecondary)
                    .lineLimit(1)
            }
        }
        .padding(compact ? 12 : 16)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .fill(theme.colorSurfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(theme.colorDivider)
        )
        .shadow(color: theme.shadows.card.color, radius: theme.shadows.card.radius, y: theme.shadows.card.y)
        .task(id: qrPreviewTaskID) {
            await loadQR()
        }
    }

    private var qrPreviewTaskID: String {
        [
            label.id.uuidString,
            label.qrPayload,
            String(printerSettings.showQRCode),
            String(printerSettings.qrRotationRaw),
            String(printerSettings.qrCornerRaw),
            String(printerSettings.qrCellSize)
        ].joined(separator: "|")
    }

    @ViewBuilder
    private var expiryBadge: some View {
        switch label.expiryState {
        case .ok:
            HACCPBadge(title: "OK", style: .conforme, showIcon: true)
        case .soon:
            HACCPBadge(title: "Presto", style: .warning, showIcon: true)
        case .expired:
            HACCPBadge(title: "Scaduto", style: .nonConforme, showIcon: true)
        }
    }

    private func labelRow(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.colorTextSecondary)
                .frame(width: 14)
            Text(text)
                .font(compact ? theme.typography.caption : theme.typography.subheadline)
                .foregroundStyle(theme.colorTextPrimary)
                .lineLimit(2)
        }
    }

    @MainActor
    private func loadQR() async {
        guard printerSettings.showQRCode else {
            qrImage = nil
            qrLoadFailed = false
            return
        }

        let payload = resolvedPayload
        let cell = LabelQRCodeLayout.clampedCellSize(
            printerSettings.qrCellSize,
            payload: payload,
            corner: printerSettings.qrCorner
        )
        let dots = LabelQRCodeLayout.printSizeDots(cellSize: cell, payload: payload)
        let dimension = max(96, CGFloat(dots) * 2)
        let rotation = printerSettings.qrRotation

        let image = await Task.detached(priority: .userInitiated) {
            ProductionLabelQRService.image(from: payload, dimension: dimension, rotation: rotation)
        }.value

        qrImage = image
        qrLoadFailed = image == nil
    }

    private var resolvedPayload: String {
        if !label.qrPayload.isEmpty { return label.qrPayload }
        return LabelQRCodeLayout.payload(for: label)
    }
}
