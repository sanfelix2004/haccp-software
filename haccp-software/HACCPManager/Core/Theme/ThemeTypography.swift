//
//  ThemeTypography.swift
//  HACCP Manager — Scala tipografica enterprise (leggibile in cucina).
//

import SwiftUI

struct ThemeTypography {
    let sizeMultiplier: Double
    let layoutMode: LayoutMode

    init(sizeMultiplier: Double = 1.0, layoutMode: LayoutMode = .comfortable) {
        self.sizeMultiplier = max(0.7, min(1.6, sizeMultiplier))
        self.layoutMode = layoutMode
    }

    private func scaled(_ base: CGFloat) -> CGFloat {
        let layoutBonus: CGFloat
        switch layoutMode {
        case .compact:     layoutBonus = -1
        case .comfortable: layoutBonus = 2
        case .largeTouch:  layoutBonus = 6
        }
        return (base + layoutBonus) * CGFloat(sizeMultiplier)
    }

    /// Hero dashboard — 42–56 pt
    var display: Font { .system(size: scaled(48), weight: .bold, design: .rounded) }
    var largeTitle: Font { .system(size: scaled(40), weight: .bold, design: .rounded) }
    var title: Font { .system(size: scaled(32), weight: .bold, design: .rounded) }
    var title2: Font { .system(size: scaled(26), weight: .semibold, design: .rounded) }
    var title3: Font { .system(size: scaled(22), weight: .semibold, design: .rounded) }
    var headline: Font { .system(size: scaled(20), weight: .semibold) }
    var body: Font { .system(size: scaled(18), weight: .regular) }
    var callout: Font { .system(size: scaled(17), weight: .regular) }
    var subheadline: Font { .system(size: scaled(16), weight: .medium) }
    var footnote: Font { .system(size: scaled(14), weight: .regular) }
    var caption: Font { .system(size: scaled(13), weight: .medium) }
    var caption2: Font { .system(size: scaled(12), weight: .regular) }
    var monoNumeric: Font { .system(size: scaled(17), weight: .semibold, design: .monospaced) }
    var statValue: Font { .system(size: scaled(36), weight: .bold, design: .rounded) }
}
