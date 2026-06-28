//
//  TraceabilityProductionArchiveCard.swift
//

import SwiftUI

/// Scheda archivio: piatto di produzione in alto, alimenti in ingresso sotto.
struct TraceabilityProductionArchiveCard: View {
    let group: TraceabilityProductionArchiveGroup
    var searchText: String = ""
    let onOpenIngredient: (UUID) -> Void

    @Environment(\.theme) private var theme
    @State private var isExpanded = false

    private var searchTokens: [String] {
        TraceabilityArchiveSearch.tokens(from: searchText)
    }

    private var shouldAutoExpand: Bool {
        !searchTokens.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                productionHeader
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(group.ingredients) { ingredient in
                        ingredientRow(ingredient)
                    }
                }
                .padding(.top, 12)
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
        .onAppear {
            if shouldAutoExpand { isExpanded = true }
        }
        .onChange(of: searchText) { _, newValue in
            if !TraceabilityArchiveSearch.tokens(from: newValue).isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = true
                }
            }
        }
    }

    private var productionHeader: some View {
        HStack(alignment: .center, spacing: 12) {
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

            VStack(alignment: .leading, spacing: 3) {
                Text(group.productionName)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    Label(group.registeredAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    Label(TraceabilityCountLabel.alimenti(group.ingredients.count), systemImage: "shippingbox")
                }
                .font(theme.typography.caption2)
                .foregroundStyle(theme.colorTextSecondary)
            }

            Spacer(minLength: 0)

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.colorTextSecondary)
                .padding(8)
        }
    }

    private func ingredientRow(_ ingredient: TraceabilityArchiveIngredientItem) -> some View {
        Button {
            onOpenIngredient(ingredient.recordId)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.colorPrimary.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "shippingbox.fill")
                            .foregroundStyle(theme.colorPrimary)
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

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colorTextSecondary.opacity(0.6))
            }
            .padding(10)
            .background(theme.colorBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PremiumPressButtonStyle())
    }
}
