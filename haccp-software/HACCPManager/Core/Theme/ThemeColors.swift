//
//  ThemeColors.swift
//  HACCP Manager — Theme System
//
//  Helpers di colore globali. NON definire qui palette specifiche: i colori
//  semantici vivono nei preset di `AppTheme` e sono accessibili dal `ThemeManager`.
//

import SwiftUI

// MARK: - Color(hex:)

extension Color {
    /// Costruttore da stringa esadecimale (#RGB, #RRGGBB, #AARRGGBB).
    /// Mantenuto qui (storicamente in `ThemeManager.swift`) perché usato da decine di views.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Mescola due colori con peso `t ∈ [0,1]` (in spazio sRGB lineare semplificato).
    func mixed(with other: Color, by t: CGFloat) -> Color {
        let clamped = max(0, min(1, t))
        let a = UIColor(self)
        let b = UIColor(other)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(
            .sRGB,
            red:     Double(ar + (br - ar) * clamped),
            green:   Double(ag + (bg - ag) * clamped),
            blue:    Double(ab + (bb - ab) * clamped),
            opacity: Double(aa + (ba - aa) * clamped)
        )
    }
}

// MARK: - Semantic color resolver

/// Calcolatore di colori "ad alto contrasto" applicato sopra un tema.
/// Quando `highContrast` è attivo aumenta la separazione tra testo e sfondo.
enum ThemeContrast {
    static func textPrimary(in theme: AppTheme, highContrast: Bool) -> Color {
        guard highContrast else { return theme.textPrimary }
        return theme.isLight ? .black : .white
    }

    static func textSecondary(in theme: AppTheme, highContrast: Bool) -> Color {
        guard highContrast else { return theme.textSecondary }
        return theme.isLight
            ? Color(hex: "#1F2937")
            : Color(hex: "#E5E7EB")
    }

    static func divider(in theme: AppTheme, highContrast: Bool) -> Color {
        guard highContrast else { return theme.divider }
        return theme.isLight
            ? Color.black.opacity(0.35)
            : ThemeManager.shared.colorTextSecondary
    }
}
