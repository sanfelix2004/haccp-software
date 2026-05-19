//
//  GlassCard.swift
//  Card vetro / enterprise con profondità.
//

import SwiftUI

struct GlassCard<Content: View>: View {
    var elevated: Bool = false
    var padding: CGFloat? = nil
    @ViewBuilder let content: () -> Content

    @Environment(\.theme) private var theme

    var body: some View {
        let corner = theme.spacing.cornerXL
        let shadow = elevated ? theme.shadows.elevated : theme.shadows.card
        let reduceFx = theme.appearance.reduceGraphicsEffects

        content()
            .padding(padding ?? theme.spacing.cardPadding)
            .background {
                ZStack {
                    if !reduceFx && theme.dashboardStyle == .glassmorphism {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(theme.colorSurface.opacity(0.55))
                    } else {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(elevated ? theme.colorSurfaceElevated : theme.colorSurface)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(theme.colorBorder.opacity(0.6), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }
}
