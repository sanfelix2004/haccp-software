//
//  TraceabilityProductionArchiveCard.swift
//

import SwiftUI

/// Scheda archivio: piatto di produzione in alto, alimenti in ingresso sotto.
struct TraceabilityProductionArchiveCard: View, Equatable {
    let group: TraceabilityProductionArchiveGroup
    var searchText: String = ""
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onOpenIngredient: (UUID) -> Void
    /// Swipe elimina sul singolo alimento (se consentito).
    var onDeleteIngredient: ((UUID) -> Void)? = nil

    @Environment(\.theme) private var theme

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.group == rhs.group
            && lhs.isExpanded == rhs.isExpanded
            && lhs.searchText == rhs.searchText
            && (lhs.onDeleteIngredient == nil) == (rhs.onDeleteIngredient == nil)
    }

    private var searchTokens: [String] {
        TraceabilityArchiveSearch.tokens(from: searchText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            productionHeader

            if isExpanded {
                ingredientsSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .stroke(theme.colorPrimary.opacity(0.15), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .onAppear {
            if !searchTokens.isEmpty, !isExpanded {
                onToggleExpanded()
            }
        }
        .onChange(of: searchText) { _, newValue in
            if !TraceabilityArchiveSearch.tokens(from: newValue).isEmpty, !isExpanded {
                onToggleExpanded()
            }
        }
    }

    private var productionHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            if let photoData = group.photoData,
               let thumb = HACCPZoomablePhotoThumbnail(
                data: photoData,
                size: 48,
                zoomTitle: group.productionName
               ) {
                thumb
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [theme.colorPrimary.opacity(0.18), theme.colorPrimary.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: "fork.knife")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.colorPrimary)
                }
            }

            Button(action: onToggleExpanded) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.productionName)
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colorTextPrimary)
                        .multilineTextAlignment(.leading)
                    if let lot = group.batchCode?.trimmingCharacters(in: .whitespacesAndNewlines), !lot.isEmpty {
                        Text("Lotto produzione \(lot)")
                            .font(theme.typography.subheadline.weight(.bold).monospaced())
                            .foregroundStyle(theme.colorPrimary)
                            .accessibilityLabel("Lotto produzione \(lot)")
                    }
                    HStack(spacing: 8) {
                        Label(group.registeredAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        Label(TraceabilityCountLabel.alimenti(group.ingredients.count), systemImage: "shippingbox")
                    }
                    .font(theme.typography.caption2)
                    .foregroundStyle(theme.colorTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: onToggleExpanded) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.colorTextSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isExpanded ? "Nascondi alimenti" : "Mostra alimenti")
        }
    }

    @ViewBuilder
    private var ingredientsSection: some View {
        if group.ingredients.isEmpty {
            Text("Nessun alimento collegato a questo piatto.")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
                .padding(.top, 12)
        } else {
            VStack(spacing: 8) {
                ForEach(group.ingredients) { ingredient in
                    ingredientRow(ingredient)
                }
            }
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private func ingredientRow(_ ingredient: TraceabilityArchiveIngredientItem) -> some View {
        if let recordId = ingredient.recordId, let onDeleteIngredient {
            SwipeToDeleteRow(
                enabled: true,
                deleteTitle: "Elimina",
                onDelete: { onDeleteIngredient(recordId) }
            ) {
                ingredientTapRow(ingredient, recordId: recordId)
            }
        } else if let recordId = ingredient.recordId {
            ingredientTapRow(ingredient, recordId: recordId)
        } else {
            ingredientRowContent(ingredient, showsChevron: false)
        }
    }

    private func ingredientTapRow(
        _ ingredient: TraceabilityArchiveIngredientItem,
        recordId: UUID
    ) -> some View {
        Button {
            onOpenIngredient(recordId)
        } label: {
            ingredientRowContent(ingredient, showsChevron: true)
        }
        .buttonStyle(PremiumPressButtonStyle())
    }

    private func ingredientRowContent(_ ingredient: TraceabilityArchiveIngredientItem, showsChevron: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            if let photoData = ingredient.photoData,
               let thumb = HACCPZoomablePhotoThumbnail(
                data: photoData,
                size: 44,
                zoomTitle: ingredient.name
               ) {
                thumb
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.colorPrimary.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "shippingbox.fill")
                            .foregroundStyle(theme.colorPrimary)
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(ingredient.name)
                    .font(theme.typography.subheadline.weight(.semibold))
                    .foregroundStyle(theme.colorTextPrimary)
                    .multilineTextAlignment(.leading)

                Text(ingredient.lotCode)
                    .font(theme.typography.caption.weight(.bold).monospaced())
                    .foregroundStyle(theme.colorPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.colorPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                if ingredient.supplier != "—" {
                    Text(ingredient.supplier)
                        .font(theme.typography.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }

            Spacer(minLength: 0)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colorTextSecondary.opacity(0.6))
            }
        }
        .padding(10)
        .background(theme.colorBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
