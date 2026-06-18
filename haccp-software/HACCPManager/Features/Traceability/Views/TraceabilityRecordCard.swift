//
//  TraceabilityRecordCard.swift
//

import SwiftUI

struct TraceabilityRecordDisplay: Equatable {
    let recordId: UUID
    let productName: String
    let lot: String
    let supplier: String
    let receivedAt: Date
    let expiryDate: Date?
    let category: String?
    let statusLabel: String
    let badgeStyle: HACCPBadgeStyle
    let productionCount: Int
    let defrostCount: Int
    let isActionable: Bool
    let expiryWarning: Bool
}

struct TraceabilityRecordCard: View {
    let display: TraceabilityRecordDisplay
    let image: UIImage?
    let onTap: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                photo
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text(display.productName)
                            .font(theme.typography.headline)
                            .foregroundStyle(theme.colorTextPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        HACCPBadge(title: display.statusLabel, style: display.badgeStyle, showIcon: false)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        metaRow(icon: "barcode", text: "Lotto \(display.lot)")
                        metaRow(icon: "building.2", text: display.supplier)
                        if let category = display.category {
                            metaRow(icon: "tag", text: category)
                        }
                        metaRow(
                            icon: "calendar",
                            text: expiryText,
                            tint: display.expiryWarning ? theme.colorWarning : theme.colorTextSecondary
                        )
                    }

                    HStack(spacing: 8) {
                        if display.productionCount > 0 {
                            pill(icon: "fork.knife", text: "\(display.productionCount) produzioni", color: theme.colorSuccess)
                        }
                        if display.defrostCount > 0 {
                            pill(icon: "snowflake", text: "Decongelato", color: theme.colorInfo)
                        }
                        if !display.isActionable {
                            pill(icon: "exclamationmark.triangle", text: "Non associabile", color: theme.colorWarning)
                        }
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colorTextSecondary)
                    .padding(.top, 4)
            }
            .padding(14)
            .background(theme.colorSurface)
            .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                    .stroke(theme.colorDivider.opacity(0.8), lineWidth: 1)
            )
        }
        .buttonStyle(PremiumPressButtonStyle())
        .accessibilityLabel("\(display.productName), \(display.statusLabel)")
        .accessibilityHint("Apri dettaglio prodotto")
    }

    @ViewBuilder
    private var photo: some View {
        if let image {
            HACCPZoomablePhotoThumbnail(
                image: image,
                size: 72,
                zoomTitle: display.productName
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.colorSurfaceElevated)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(theme.colorTextSecondary)
                }
        }
    }

    private var expiryText: String {
        if let expiry = display.expiryDate {
            return "Scadenza \(expiry.formatted(date: .abbreviated, time: .omitted))"
        }
        return "Scadenza non indicata"
    }

    private func metaRow(icon: String, text: String, tint: Color? = nil) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .frame(width: 14)
            Text(text)
                .font(theme.typography.caption)
                .lineLimit(1)
        }
        .foregroundStyle(tint ?? theme.colorTextSecondary)
    }

    private func pill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(theme.typography.caption2.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}
