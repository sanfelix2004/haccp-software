//
//  ThemeTypography.swift
//  HACCP Manager — Theme System
//
//  Token tipografici. Le views possono usare `.font(theme.typography.title)` ecc.
//  La scala si adatta al `textSizeModifier` per accessibilità.
//

import SwiftUI

struct ThemeTypography {
    let sizeMultiplier: Double          // 0.85..1.4 — da AppearanceSettings.textSizeModifier
    let layoutMode: LayoutMode

    init(sizeMultiplier: Double = 1.0, layoutMode: LayoutMode = .comfortable) {
        self.sizeMultiplier = max(0.7, min(1.6, sizeMultiplier))
        self.layoutMode = layoutMode
    }

    private func scaled(_ base: CGFloat) -> CGFloat {
        let layoutBonus: CGFloat
        switch layoutMode {
        case .compact:     layoutBonus = -1
        case .comfortable: layoutBonus = 0
        case .largeTouch:  layoutBonus = 2
        }
        return (base + layoutBonus) * CGFloat(sizeMultiplier)
    }

    var largeTitle: Font  { .system(size: scaled(34), weight: .bold,     design: .rounded) }
    var title:      Font  { .system(size: scaled(28), weight: .bold,     design: .rounded) }
    var title2:     Font  { .system(size: scaled(22), weight: .semibold, design: .rounded) }
    var title3:     Font  { .system(size: scaled(20), weight: .semibold, design: .rounded) }
    var headline:   Font  { .system(size: scaled(17), weight: .semibold) }
    var body:       Font  { .system(size: scaled(16), weight: .regular) }
    var callout:    Font  { .system(size: scaled(15), weight: .regular) }
    var subheadline:Font  { .system(size: scaled(14), weight: .medium) }
    var footnote:   Font  { .system(size: scaled(13), weight: .regular) }
    var caption:    Font  { .system(size: scaled(12), weight: .regular) }
    var caption2:   Font  { .system(size: scaled(11), weight: .regular) }

    /// Numerica monospace usata per dati HACCP (temperature, lotti, percentuali).
    var monoNumeric: Font { .system(size: scaled(15), weight: .semibold, design: .monospaced) }
}
