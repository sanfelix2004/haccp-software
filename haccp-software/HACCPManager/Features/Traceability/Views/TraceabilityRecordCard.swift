//
//  TraceabilityRecordCard.swift
//

import SwiftUI

enum TraceabilityCountLabel {
    static func piatti(_ count: Int) -> String {
        count == 1 ? "1 piatto" : "\(count) piatti"
    }

    static func alimenti(_ count: Int) -> String {
        count == 1 ? "1 alimento" : "\(count) alimenti"
    }

    static func piattiEAlimenti(productionCount: Int, ingredientCount: Int) -> String {
        "\(piatti(productionCount)) · \(alimenti(ingredientCount))"
    }
}

struct TraceabilityRecordDisplay: Equatable {
    let recordId: UUID
    let productName: String
    let lot: String
    let supplier: String
    let receivedAt: Date
    let category: String?
    let statusLabel: String
    let badgeStyle: HACCPBadgeStyle
    let productionCount: Int
    let linkedIngredientCount: Int
    let defrostCount: Int
    let isActionable: Bool
    let needsProductionLink: Bool
    /// True se il codice è un lotto di produzione (YYYYMMDD-XX / batch output).
    var isProductionLot: Bool = false
}

struct TraceabilityRecordCard: View {
    let display: TraceabilityRecordDisplay
    var photoData: Data? = nil
    let onTap: () -> Void
    var onQuickAssociate: (() -> Void)? = nil

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
                        statusBadge
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        metaRow(
                            icon: "barcode",
                            text: display.isProductionLot
                                ? "Lotto produzione \(display.lot)"
                                : "Lotto \(display.lot)"
                        )
                        if display.supplier != "—" {
                            metaRow(icon: "building.2", text: display.supplier)
                        }
                        if let category = display.category {
                            metaRow(icon: "tag", text: category)
                        }
                        metaRow(
                            icon: "calendar",
                            text: "Registrato \(display.receivedAt.formatted(date: .abbreviated, time: .omitted))"
                        )
                    }

                    footerRow
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
                    .stroke(borderColor, lineWidth: display.needsProductionLink ? 1.5 : 1)
            )
        }
        .buttonStyle(PremiumPressButtonStyle())
        .accessibilityLabel("\(display.productName), \(display.statusLabel)")
        .accessibilityHint("Apri dettaglio prodotto")
    }

    private var statusBadge: some View {
        HACCPBadge(title: display.statusLabel, style: display.badgeStyle, showIcon: false)
    }

    private var borderColor: Color {
        if display.needsProductionLink {
            return theme.colorPrimary.opacity(0.45)
        }
        return theme.colorDivider.opacity(0.8)
    }

    @ViewBuilder
    private var footerRow: some View {
        HStack(spacing: 8) {
            if display.productionCount > 0 {
                pill(
                    icon: "fork.knife",
                    text: TraceabilityCountLabel.piattiEAlimenti(
                        productionCount: display.productionCount,
                        ingredientCount: display.linkedIngredientCount
                    ),
                    color: theme.colorSuccess
                )
            } else if display.needsProductionLink, let onQuickAssociate {
                Button {
                    onQuickAssociate()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "link.badge.plus")
                            .font(.caption2.weight(.bold))
                        Text("Associa piatto")
                            .font(theme.typography.caption2.weight(.semibold))
                    }
                    .foregroundStyle(theme.colorPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.colorPrimary.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            if display.defrostCount > 0 {
                pill(icon: "snowflake", text: "Decongelato", color: theme.colorInfo)
            }
            if !display.isActionable {
                pill(icon: "lock.fill", text: "Chiuso", color: theme.colorTextSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var photo: some View {
        if let photoData,
           let thumb = HACCPZoomablePhotoThumbnail(
            data: photoData,
            size: 72,
            zoomTitle: display.productName
           ) {
            thumb
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.colorPrimary.opacity(0.1))
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "shippingbox.fill")
                        .font(.title3)
                        .foregroundStyle(theme.colorPrimary)
                }
        }
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
