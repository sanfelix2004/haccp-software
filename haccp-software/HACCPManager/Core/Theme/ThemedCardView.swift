//
//  ThemedCardView.swift
//  Card dashboard enterprise.
//

import SwiftUI

struct DashboardCardView<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var help: ModuleHelp? = nil
    @ViewBuilder let content: Content

    @Environment(\.theme) private var theme

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(theme.typography.title3)
                            .foregroundStyle(theme.colorTextPrimary)
                        if let subtitle {
                            Text(subtitle)
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                    if let help {
                        ModuleHelpButton(help: help, size: 32)
                    }
                }
                content
            }
        }
    }
}

struct DashboardEmptyStateView: View {
    let state: DashboardEmptyState
    var action: (() -> Void)? = nil

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            ZStack {
                Circle()
                    .fill(theme.colorPrimary.opacity(0.1))
                    .frame(width: 72, height: 72)
                Image(systemName: "tray.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(theme.colorPrimary)
            }
            Text(state.title)
                .font(theme.typography.title3)
                .foregroundStyle(theme.colorTextPrimary)
            Text(state.message)
                .font(theme.typography.body)
                .foregroundStyle(theme.colorTextSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle = state.actionTitle, let action {
                PrimaryButton(title: actionTitle, icon: "plus.circle.fill", action: action)
                    .frame(maxWidth: 280)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.xxl)
    }
}

/// Tile modulo dashboard con press animation.
struct ModuleTileView: View {
    let title: String
    let icon: String
    let description: String
    var badge: Int? = nil

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.colorPrimary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.colorPrimary)
                }
                Spacer()
                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(theme.typography.caption.weight(.bold))
                        .foregroundStyle(theme.colorTextOnPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.colorPrimary)
                        .clipShape(Capsule())
                }
            }
            Text(title)
                .font(theme.typography.headline)
                .foregroundStyle(theme.colorTextPrimary)
                .lineLimit(2)
            Text(description)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: theme.spacing.dashboardTileMinHeight, alignment: .topLeading)
        .padding(theme.spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .fill(theme.colorSurfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .stroke(theme.colorDivider.opacity(0.8), lineWidth: 1)
        )
    }
}
