//
//  ThemeShadows.swift
//  HACCP Manager — Ombre semantiche (no hardcode nelle view).
//

import SwiftUI

struct ThemeShadows {
    let isLight: Bool
    let reduceEffects: Bool

    init(theme: AppTheme, reduceEffects: Bool) {
        self.isLight = theme.isLight
        self.reduceEffects = reduceEffects
    }

    var card: (color: Color, radius: CGFloat, y: CGFloat) {
        guard !reduceEffects else { return (.clear, 0, 0) }
        if isLight {
            return (Color.black.opacity(0.08), 16, 6)
        }
        return (Color.black.opacity(0.45), 24, 12)
    }

    var elevated: (color: Color, radius: CGFloat, y: CGFloat) {
        guard !reduceEffects else { return (.clear, 0, 0) }
        if isLight {
            return (Color.black.opacity(0.12), 20, 8)
        }
        return (Color.black.opacity(0.55), 32, 16)
    }

    var subtle: (color: Color, radius: CGFloat, y: CGFloat) {
        guard !reduceEffects else { return (.clear, 0, 0) }
        return (Color.black.opacity(isLight ? 0.04 : 0.35), 8, 3)
    }

    var glowPrimary: (color: Color, radius: CGFloat) {
        guard !reduceEffects else { return (.clear, 0) }
        return (Color.red.opacity(isLight ? 0.15 : 0.35), 18)
    }
}

extension ThemeManager {
    var shadows: ThemeShadows {
        ThemeShadows(theme: currentTheme, reduceEffects: appearance.reduceGraphicsEffects)
    }
}
