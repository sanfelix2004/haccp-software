//
//  ThemedModifiers.swift
//  HACCP Manager — Theme System
//
//  Modificatori SwiftUI di alto livello per applicare il tema corrente
//  in modo dichiarativo, senza mai hard-codare colori nelle views.
//
//  Esempi:
//      MyView().themedScreen()
//      MyCard().themedCard()
//      Text("...").themedHeadline()
//

import SwiftUI

// MARK: - Background sistema globale

/// View standalone che disegna il background root seguendo lo stile selezionato
/// (solid / gradient / minimal / texture / animated). Usato direttamente da
/// `ContentView` e ovunque serva il background del tema.
struct ThemedRootBackground: View {
    var manager: ThemeManager = .shared

    var body: some View {
        let theme = manager.currentTheme
        let style = manager.backgroundStyle
        let reduceFx = manager.appearance.reduceGraphicsEffects

        Group {
            switch style {
            case .solid:
                theme.background
            case .gradient:
                if let end = theme.backgroundEnd {
                    LinearGradient(
                        colors: [theme.background, end],
                        startPoint: .topLeading,
                        endPoint:   .bottomTrailing
                    )
                } else {
                    theme.background
                }
            case .minimal:
                theme.background.opacity(theme.isLight ? 0.98 : 1.0)
            case .texture:
                ZStack {
                    theme.background
                    if !reduceFx {
                        Color.white.opacity(theme.isLight ? 0.02 : 0.015)
                            .blendMode(.overlay)
                    }
                }
            case .animated:
                if reduceFx {
                    theme.background
                } else {
                    AnimatedAuroraBackground(theme: theme)
                }
            }
        }
    }
}

/// Modificatore per applicare il background del tema a una singola schermata.
struct ThemedScreenBackground: ViewModifier {
    var manager: ThemeManager = .shared
    func body(content: Content) -> some View {
        content.background(ThemedRootBackground(manager: manager).ignoresSafeArea())
    }
}

/// Aurora animata leggera per il preset Kitchen Neon / Midnight Blue.
private struct AnimatedAuroraBackground: View {
    let theme: AppTheme
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            theme.background

            // Due "blob" che oscillano lentamente.
            Circle()
                .fill(theme.primary.opacity(0.22))
                .frame(width: 480, height: 480)
                .blur(radius: 120)
                .offset(x: -120 + 40 * sin(phase),
                        y: -200 + 30 * cos(phase * 0.8))

            Circle()
                .fill((theme.glow ?? theme.accent).opacity(0.18))
                .frame(width: 420, height: 420)
                .blur(radius: 140)
                .offset(x: 160 + 50 * cos(phase * 1.1),
                        y:  260 + 35 * sin(phase * 0.9))
        }
        .compositingGroup()
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Card sistema

/// Card / pannello che adotta lo stile della dashboard attiva
/// (Cards Classic / Glassmorphism / Minimal Flat / Enterprise / Modern Neon).
struct ThemedCard: ViewModifier {
    var manager: ThemeManager = .shared

    func body(content: Content) -> some View {
        let theme = manager.currentTheme
        let style = manager.dashboardStyle
        let spacing = manager.spacing
        let reduceFx = manager.appearance.reduceGraphicsEffects
        let corner = style.cardCornerRadiusBase * manager.layoutMode.densityMultiplier

        content
            .padding(spacing.cardPadding)
            .background(
                ZStack {
                    if style == .glassmorphism && !reduceFx {
                        // Vetro
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(theme.surface.opacity(style.cardBackgroundOpacity * 4))
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(.ultraThinMaterial)
                    } else {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(theme.surface)
                    }

                    // Glow accent per Modern Neon
                    if style.usesAccentGlow && !reduceFx {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .stroke(theme.primary.opacity(0.5), lineWidth: 1)
                            .shadow(color: (theme.glow ?? theme.primary).opacity(0.6),
                                    radius: 12)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(theme.border.opacity(style.cardStrokeOpacity * 3), lineWidth: 0.5)
            )
            .shadow(
                color: Color.black.opacity(reduceFx ? 0 : style.cardShadowOpacity),
                radius: reduceFx ? 0 : 12,
                x: 0, y: 6
            )
    }
}

// MARK: - Bottoni primari tematizzati

struct ThemedPrimaryButton: ViewModifier {
    var manager: ThemeManager = .shared

    func body(content: Content) -> some View {
        let theme = manager.currentTheme
        let spacing = manager.spacing
        content
            .font(manager.typography.headline)
            .foregroundStyle(theme.textOnPrimary)
            .padding(.horizontal, spacing.buttonHorizontalPadding)
            .padding(.vertical,   spacing.buttonVerticalPadding)
            .frame(minHeight: spacing.buttonMinHeight)
            .background(
                RoundedRectangle(cornerRadius: spacing.buttonCornerRadius, style: .continuous)
                    .fill(theme.primary)
            )
            .contentShape(Rectangle())
    }
}

// MARK: - Testi tematizzati

struct ThemedHeadlineText: ViewModifier {
    var manager: ThemeManager = .shared
    func body(content: Content) -> some View {
        content
            .font(manager.typography.headline)
            .foregroundStyle(manager.colorTextPrimary)
    }
}

struct ThemedBodyText: ViewModifier {
    var manager: ThemeManager = .shared
    func body(content: Content) -> some View {
        content
            .font(manager.typography.body)
            .foregroundStyle(manager.colorTextPrimary)
    }
}

struct ThemedCaptionText: ViewModifier {
    var manager: ThemeManager = .shared
    func body(content: Content) -> some View {
        content
            .font(manager.typography.caption)
            .foregroundStyle(manager.colorTextSecondary)
    }
}

// MARK: - Convenience API

extension View {
    /// Applica il background di schermata definito dal tema.
    func themedScreen(_ manager: ThemeManager = .shared) -> some View {
        modifier(ThemedScreenBackground(manager: manager))
    }

    /// Avvolge il contenuto in una card che segue lo stile dashboard corrente.
    func themedCard(_ manager: ThemeManager = .shared) -> some View {
        modifier(ThemedCard(manager: manager))
    }

    func themedPrimaryButton(_ manager: ThemeManager = .shared) -> some View {
        modifier(ThemedPrimaryButton(manager: manager))
    }

    func themedHeadline(_ manager: ThemeManager = .shared) -> some View {
        modifier(ThemedHeadlineText(manager: manager))
    }

    func themedBody(_ manager: ThemeManager = .shared) -> some View {
        modifier(ThemedBodyText(manager: manager))
    }

    func themedCaption(_ manager: ThemeManager = .shared) -> some View {
        modifier(ThemedCaptionText(manager: manager))
    }
}
