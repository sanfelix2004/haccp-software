//
//  PremiumButtons.swift
//  Bottoni enterprise touch-friendly.
//

import SwiftUI

// MARK: - Press style

struct PremiumPressButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// MARK: - Primary

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(theme.colorTextOnPrimary)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.headline.weight(.semibold))
                }
                Text(title)
                    .font(theme.typography.headline)
            }
            .foregroundStyle(theme.colorTextOnPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: theme.spacing.buttonMinHeight)
            .background(
                RoundedRectangle(cornerRadius: theme.spacing.buttonCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.colorPrimary, theme.colorPrimary.opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(
                color: theme.shadows.glowPrimary.color,
                radius: theme.shadows.glowPrimary.radius,
                y: 4
            )
        }
        .buttonStyle(PremiumPressButtonStyle())
        .disabled(isLoading)
    }
}

// MARK: - Secondary

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(theme.typography.headline)
            }
            .foregroundStyle(theme.colorTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: theme.spacing.buttonMinHeight)
            .background(
                RoundedRectangle(cornerRadius: theme.spacing.buttonCornerRadius, style: .continuous)
                    .fill(theme.colorSurfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.spacing.buttonCornerRadius, style: .continuous)
                    .stroke(theme.colorDivider, lineWidth: 1)
            )
        }
        .buttonStyle(PremiumPressButtonStyle())
    }
}

// MARK: - Danger

struct DangerButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(theme.typography.headline)
            }
            .foregroundStyle(theme.colorTextOnPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: theme.spacing.buttonMinHeight)
            .background(
                RoundedRectangle(cornerRadius: theme.spacing.buttonCornerRadius, style: .continuous)
                    .fill(theme.colorError)
            )
        }
        .buttonStyle(PremiumPressButtonStyle())
    }
}

// MARK: - Ghost

struct GhostButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(theme.typography.subheadline.weight(.semibold))
            }
            .foregroundStyle(theme.colorPrimary)
            .frame(minHeight: 44)
            .padding(.horizontal, theme.spacing.lg)
        }
        .buttonStyle(PremiumPressButtonStyle(scale: 0.98))
    }
}
