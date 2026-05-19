//
//  ThemedUI.swift
//  HACCP Manager — Controlli UI leggibili su tema chiaro (bottoni, tint, link).
//

import SwiftUI

extension ThemeManager {
    /// Tint globale per bottoni, link, toggle, picker.
    var controlTint: Color { colorPrimary }
}

extension View {
    /// Applica tint rosso HACCP a bottoni e controlli (sostituisce `.tint(ThemeManager.shared.colorPrimary)`).
    func haccpControlTint() -> some View {
        tint(ThemeManager.shared.colorPrimary)
    }

    /// Testo principale leggibile su sfondo chiaro.
    func haccpTextPrimary() -> some View {
        foregroundStyle(ThemeManager.shared.colorTextPrimary)
    }

    /// Testo secondario.
    func haccpTextSecondary() -> some View {
        foregroundStyle(ThemeManager.shared.colorTextSecondary)
    }

    /// Stile bottone primario pieno (rosso + testo bianco).
    func haccpPrimaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundStyle(ThemeManager.shared.colorTextOnPrimary)
            .padding(.horizontal, ThemeManager.shared.spacing.lg)
            .padding(.vertical, ThemeManager.shared.spacing.md)
            .background(ThemeManager.shared.colorPrimary)
            .clipShape(RoundedRectangle(cornerRadius: ThemeManager.shared.spacing.cornerMedium, style: .continuous))
    }
}
