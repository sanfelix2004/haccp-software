//
//  ProductionLabelRowView.swift
//

import SwiftUI
import SwiftData

struct ProductionLabelRowView: View {
    let label: ProductionLabelRecord

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @State private var photoData: Data?

    var body: some View {
        HStack(spacing: 14) {
            leadingVisual

            VStack(alignment: .leading, spacing: 4) {
                Text(label.productName)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                HACCPBadge(title: label.labelStatus.label, style: statusStyle, showIcon: false)
                if label.expiryState != .ok {
                    HACCPBadge(title: label.expiryState.badgeTitle, style: expiryStyle, showIcon: true)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.colorTextSecondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .fill(theme.colorSurface)
        )
        .task(id: label.id) {
            photoData = ProductionLabelImageResolver.imageData(for: label, context: modelContext)
        }
    }

    @ViewBuilder
    private var leadingVisual: some View {
        if let photoData,
           let thumb = HACCPZoomablePhotoThumbnail(data: photoData, size: 44, zoomTitle: label.productName) {
            thumb
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.colorPrimary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: label.sourceModule.icon)
                    .foregroundStyle(theme.colorPrimary)
            }
        }
    }

    private var subtitle: String {
        let lot = label.lotCode.map { "Lotto \($0) · " } ?? ""
        return "\(lot)Scad. \(label.expiryDate.formatted(date: .abbreviated, time: .omitted))"
    }

    private var statusStyle: HACCPBadgeStyle {
        switch label.labelStatus {
        case .active: return .conforme
        case .draft: return .neutral
        case .reprinted: return .info
        case .voided: return .nonConforme
        }
    }

    private var expiryStyle: HACCPBadgeStyle {
        switch label.expiryState {
        case .ok: return .conforme
        case .soon: return .warning
        case .expired: return .nonConforme
        }
    }
}
