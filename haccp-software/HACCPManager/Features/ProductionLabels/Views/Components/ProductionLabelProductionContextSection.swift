import SwiftUI

/// Sezione produzione + ingredienti associati (anche chiusi / scartati / scaduti).
struct ProductionLabelProductionContextSection: View {
    let context: ProductionLabelProductionContext

    @Environment(\.theme) private var theme

    var body: some View {
        if context.hasProductionInfo {
            VStack(spacing: theme.spacing.sectionSpacing) {
                productionCard
                if !context.ingredients.isEmpty {
                    ingredientsCard
                }
            }
        }
    }

    private var productionCard: some View {
        DashboardCardView(
            title: "Produzione collegata",
            subtitle: "Dati completi del piatto / batch"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if let name = context.productionName, !name.isEmpty {
                    row("Piatto / produzione", name, icon: "fork.knife")
                }
                if let category = context.productionCategory, !category.isEmpty {
                    row("Categoria", category, icon: "square.grid.2x2")
                }
                if let lot = context.batchCode, !lot.isEmpty {
                    row("Lotto produzione", lot, icon: "barcode")
                }
                if let produced = context.producedAt {
                    row(
                        "Prodotto il",
                        produced.formatted(date: .abbreviated, time: .shortened),
                        icon: "calendar"
                    )
                }
                if let op = context.batchOperator, !op.isEmpty {
                    row("Operatore produzione", op, icon: "person.fill")
                }
                if context.isBatchArchived {
                    row("Stato batch", "Archiviato / nascosto dallo storico UI", icon: "archivebox.fill")
                }
                if let outLot = context.outputLotCode, !outLot.isEmpty {
                    row("Lotto piatto finito", outLot, icon: "tag.fill")
                }
                if let outStatus = context.outputStatusLabel, !outStatus.isEmpty {
                    row("Stato piatto finito", outStatus, icon: "checkmark.seal")
                }
                if let outExp = context.outputExpiryDate {
                    row(
                        "Scadenza piatto",
                        outExp.formatted(date: .abbreviated, time: .omitted),
                        icon: "clock.badge.exclamationmark"
                    )
                }
                if let notes = context.batchNotes, !notes.isEmpty {
                    row("Note produzione", notes, icon: "note.text")
                }
            }
        }
    }

    private var ingredientsCard: some View {
        DashboardCardView(
            title: "Elementi associati",
            subtitle: "Tutti i lotti collegati — anche scartati, scaduti o chiusi"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(context.ingredients) { item in
                    ingredientBlock(item)
                    if item.id != context.ingredients.last?.id {
                        Divider().opacity(0.35)
                    }
                }
            }
        }
    }

    private func ingredientBlock(_ item: ProductionLabelLinkedIngredient) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let data = item.photoData,
               let thumb = HACCPZoomablePhotoThumbnail(
                data: data,
                size: 48,
                zoomTitle: item.name
               ) {
                thumb
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.colorSurfaceElevated)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "shippingbox")
                            .foregroundStyle(theme.colorTextSecondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(theme.typography.subheadline.weight(.semibold))
                    .foregroundStyle(theme.colorTextPrimary)
                Text("Lotto \(item.lotCode) · \(item.supplier)")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                if let expiry = item.expiryDate {
                    Text("Scadenza \(expiry.formatted(date: .abbreviated, time: .omitted))")
                        .font(theme.typography.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                }
                HStack(spacing: 6) {
                    HACCPBadge(title: item.statusLabel, style: statusStyle(for: item), showIcon: false)
                    if item.isArchivedFromHistory {
                        HACCPBadge(title: "Nascosto storico", style: .neutral, showIcon: false)
                    }
                }
                if let detail = item.detailNote, !detail.isEmpty {
                    Text(detail)
                        .font(theme.typography.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func statusStyle(for item: ProductionLabelLinkedIngredient) -> HACCPBadgeStyle {
        let s = item.statusLabel.lowercased()
        if s.contains("scart") || s.contains("respint") || s.contains("non conform") {
            return .nonConforme
        }
        if s.contains("scadut") {
            return .warning
        }
        if s.contains("chius") || s.contains("terminat") || s.contains("usat") {
            return .info
        }
        return .conforme
    }

    private func row(_ title: String, _ value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.colorTextSecondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                Text(value)
                    .font(theme.typography.subheadline)
                    .foregroundStyle(theme.colorTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
