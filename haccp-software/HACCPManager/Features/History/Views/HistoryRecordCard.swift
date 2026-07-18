import SwiftUI

struct HistoryRecordCard: View, Equatable {
    let entry: HistoryEntry
    var isLastInSection: Bool = false
    var onPendingClosure: ((UUID) -> Void)? = nil

    static func == (lhs: HistoryRecordCard, rhs: HistoryRecordCard) -> Bool {
        lhs.entry == rhs.entry && lhs.isLastInSection == rhs.isLastInSection
    }

    @Environment(\.theme) private var theme
    @State private var isExpanded = false
    @State private var selectedIngredientId: IdentifiableUUID? = nil

    private var accent: Color {
        entry.module.accentColor(theme: theme)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            timelineRail

            VStack(alignment: .leading, spacing: 10) {
                if let ingredients = entry.traceabilityIngredients {
                    traceabilityProductionCard(ingredients: ingredients)
                } else {
                    standardCard
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                    .strokeBorder(
                        entry.hasCriticality ? theme.colorError.opacity(0.35) : theme.colorDivider.opacity(0.7),
                        lineWidth: 1
                    )
            )
        }
        .sheet(item: $selectedIngredientId) { wrapper in
            TraceabilityRecordHistoryDetailSheet(recordId: wrapper.id) {
                selectedIngredientId = nil
            }
        }
    }

    @ViewBuilder
    private var standardCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            header(showExpandHint: entry.requiresClosureAction || !entry.details.isEmpty || entry.photoData != nil)
            if let photo = entry.photoData,
               let thumb = HACCPZoomablePhotoThumbnail(
                data: photo,
                size: 96,
                zoomTitle: entry.title
               ) {
                thumb
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if entry.requiresClosureAction {
                Button {
                    if let recordId = entry.pendingTraceabilityRecordId {
                        onPendingClosure?(recordId)
                    }
                } label: {
                    Label("Registra usato o scartato", systemImage: "hand.tap.fill")
                        .font(theme.typography.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            } else if isExpanded, !entry.details.isEmpty {
                detailsGrid
                    .transition(.opacity.combined(with: .move(edge: .top)))

                if let photo = entry.photoData {
                    photoCard(photo)
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if entry.requiresClosureAction {
                if let recordId = entry.pendingTraceabilityRecordId {
                    onPendingClosure?(recordId)
                }
                return
            }
            guard !entry.details.isEmpty || entry.photoData != nil else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                isExpanded.toggle()
            }
        }
    }

    @ViewBuilder
    private func traceabilityProductionCard(ingredients: [HistoryTraceabilityIngredient]) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                isExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    if let photo = entry.photoData,
                       let thumb = HACCPZoomablePhotoThumbnail(
                        data: photo,
                        size: 52,
                        zoomTitle: entry.title
                       ) {
                        thumb
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(accent.opacity(0.14))
                                .frame(width: 44, height: 44)
                            Image(systemName: "fork.knife")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(accent)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title)
                            .font(theme.typography.headline)
                            .foregroundStyle(theme.colorTextPrimary)
                            .multilineTextAlignment(.leading)
                        if let lot = entry.internalLotCode?.trimmingCharacters(in: .whitespacesAndNewlines), !lot.isEmpty {
                            Text("Lotto produzione \(lot)")
                                .font(theme.typography.caption.weight(.bold).monospaced())
                                .foregroundStyle(theme.colorPrimary)
                        }
                        Text(entry.status)
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(entry.date.formatted(date: .omitted, time: .shortened))
                            .font(theme.typography.caption.weight(.semibold))
                            .foregroundStyle(theme.colorTextSecondary)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.colorPrimary)
                    }
                }

                if isExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        if let lot = entry.internalLotCode?.trimmingCharacters(in: .whitespacesAndNewlines), !lot.isEmpty {
                            ProductionInternalLotBadge(batchCode: lot, compact: true)
                        }
                        if let photo = entry.photoData {
                            photoCard(photo)
                        }
                        VStack(spacing: 8) {
                            ForEach(ingredients) { ingredient in
                                Button {
                                    selectedIngredientId = IdentifiableUUID(id: ingredient.id)
                                } label: {
                                    ingredientRow(ingredient)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func ingredientRow(_ ingredient: HistoryTraceabilityIngredient) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let photo = ingredient.photoData,
               let thumb = HACCPZoomablePhotoThumbnail(
                data: photo,
                size: 44,
                zoomTitle: ingredient.name
               ) {
                thumb
            } else {
                Image(systemName: "shippingbox.fill")
                    .font(.caption)
                    .foregroundStyle(theme.colorPrimary)
                    .frame(width: 20)
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(ingredient.name)
                    .font(theme.typography.subheadline.weight(.semibold))
                    .foregroundStyle(theme.colorTextPrimary)
                Text("Lotto \(ingredient.lotCode)")
                    .font(theme.typography.caption.weight(.bold).monospaced())
                    .foregroundStyle(theme.colorPrimary)
                if ingredient.supplier != "—" {
                    Text(ingredient.supplier)
                        .font(theme.typography.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                }
                HStack(spacing: 8) {
                    if ingredient.expiryText != "—" {
                        Label(ingredient.expiryText, systemImage: "calendar")
                    }
                    Text(ingredient.operatorName)
                }
                .font(theme.typography.caption2)
                .foregroundStyle(theme.colorTextSecondary)
            }

            Spacer(minLength: 0)

            if ingredient.hasCriticality {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(theme.colorError)
            }
        }
        .padding(10)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var timelineRail: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(entry.hasCriticality ? theme.colorError : accent)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .strokeBorder(theme.colorBackground, lineWidth: 2)
                )
            if !isLastInSection {
                Rectangle()
                    .fill(theme.colorDivider.opacity(0.8))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 12)
        .padding(.top, 18)
    }

    private func header(showExpandHint: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colorTextPrimary)
                        .lineLimit(isExpanded ? nil : 2)
                    Text(entry.operatorName)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(theme.colorTextSecondary)
                    HACCPBadge(title: entry.status, style: entry.statusBadgeStyle, showIcon: false)
                }
            }

            if let lot = entry.internalLotCode?.trimmingCharacters(in: .whitespacesAndNewlines), !lot.isEmpty {
                Text("Lotto produzione \(lot)")
                    .font(theme.typography.caption.weight(.bold).monospaced())
                    .foregroundStyle(theme.colorPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.colorPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            HStack(spacing: 8) {
                if !entry.category.isEmpty, entry.category != "—" {
                    Label(entry.category, systemImage: "folder")
                        .font(theme.typography.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                        .lineLimit(1)
                }
                Spacer()
                if showExpandHint {
                    Label(isExpanded ? "Meno dettagli" : "Dettagli", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                        .font(theme.typography.caption2.weight(.semibold))
                        .foregroundStyle(theme.colorPrimary)
                }
            }
        }
    }

    private var detailsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
            ForEach(entry.details) { detail in
                VStack(alignment: .leading, spacing: 3) {
                    Text(detail.label.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(theme.colorTextSecondary)
                        .tracking(0.4)
                    Text(detail.value)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextPrimary)
                        .lineLimit(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(theme.colorSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func photoCard(_ data: Data) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DOCUMENTAZIONE FOTOGRAFICA")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(theme.colorTextSecondary)
                .tracking(0.4)

            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(10)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var cardBackground: Color {
        entry.hasCriticality ? theme.colorError.opacity(0.07) : theme.colorSurfaceElevated
    }
}

// MARK: - IdentifiableUUID
struct IdentifiableUUID: Identifiable {
    let id: UUID
}

