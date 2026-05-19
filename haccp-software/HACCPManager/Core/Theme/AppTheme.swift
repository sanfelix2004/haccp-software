//
//  AppTheme.swift
//  HACCP Manager — Theme System
//
//  Definizione del Theme + 6 preset enterprise predefiniti.
//  Le views NON devono mai accedere agli hex direttamente: usare i Color computed.
//

import Foundation
import SwiftUI

/// Tema completo dell'app. Contiene tutti i token cromatici e stilistici.
/// Codable per persistenza e per il sistema di import/export futuro.
struct AppTheme: Identifiable, Hashable, Codable {

    // Identità
    let id: String
    let name: String
    let descriptionText: String
    let isLight: Bool

    // Palette base
    let backgroundHex: String          // sfondo principale schermate
    let backgroundEndHex: String?      // colore finale del gradiente di sfondo (se gradient)
    let surfaceHex: String             // card / pannelli
    let surfaceElevatedHex: String     // card elevate (modal, sheet, popover)
    let dividerHex: String

    // Brand
    let primaryHex: String             // brand HACCP (es. rosso)
    let accentHex: String              // accenti decorativi (es. oro / ciano)
    let secondaryHex: String           // colore di supporto (informativo)

    // Tipografia
    let textPrimaryHex: String
    let textSecondaryHex: String
    let textOnPrimaryHex: String       // testo su bottoni primari

    // Semantica HACCP
    let successHex: String
    let warningHex: String
    let errorHex: String
    let infoHex: String

    // Bordi e ombre
    let borderHex: String
    let glowAccentHex: String?         // alone neon (Modern Neon)

    // Var. stilistiche di default per questo preset
    let defaultDashboardStyle: DashboardStyle
    let defaultSidebarStyle: SidebarStyle
    let defaultBackgroundStyle: BackgroundStyle
    let cornerRadiusBase: CGFloat
    let prefersDarkColorScheme: Bool

    // MARK: Colors (computed)

    var background: Color        { Color(hex: backgroundHex) }
    var backgroundEnd: Color?    { backgroundEndHex.map { Color(hex: $0) } }
    var surface: Color           { Color(hex: surfaceHex) }
    var surfaceElevated: Color   { Color(hex: surfaceElevatedHex) }
    var divider: Color           { Color(hex: dividerHex) }
    var primary: Color           { Color(hex: primaryHex) }
    var accent: Color            { Color(hex: accentHex) }
    var secondary: Color         { Color(hex: secondaryHex) }
    var textPrimary: Color       { Color(hex: textPrimaryHex) }
    var textSecondary: Color     { Color(hex: textSecondaryHex) }
    var textOnPrimary: Color     { Color(hex: textOnPrimaryHex) }
    var success: Color           { Color(hex: successHex) }
    var warning: Color           { Color(hex: warningHex) }
    var error: Color             { Color(hex: errorHex) }
    var info: Color              { Color(hex: infoHex) }
    var border: Color            { Color(hex: borderHex) }
    var glow: Color?             { glowAccentHex.map { Color(hex: $0) } }
}

// MARK: - Preset gallery

extension AppTheme {

    /// Identificativi stabili delle preset. Usati per persistenza.
    enum PresetID {
        static let darkPremium   = "dark_premium"
        static let lightPremium  = "light_premium"
        static let midnight      = "midnight"
        static let haccpRed      = "haccp_red"
        static let minimalWhite  = "minimal_white"
        // Legacy IDs (migrazione automatica)
        static let haccpDarkPro  = "haccp_dark_pro"
        static let haccpLightPro = "haccp_light_pro"
        static let midnightBlue  = "midnight_blue"
        static let kitchenNeon   = "kitchen_neon"
        static let cleanWhite    = "clean_white"
    }

    /// Preset selezionabili in Impostazioni → Aspetto.
    static let allPresets: [AppTheme] = [
        .darkPremium,
        .lightPremium,
        .midnight,
        .haccpRed,
        .minimalWhite
    ]

    /// Preset di default in caso di prima esecuzione o ID non riconosciuto.
    static let defaultPreset: AppTheme = .darkPremium

    static func preset(forID id: String) -> AppTheme {
        let migrated: String = {
            switch id {
            case PresetID.haccpDarkPro: return PresetID.darkPremium
            case PresetID.haccpLightPro: return PresetID.lightPremium
            case PresetID.midnightBlue: return PresetID.midnight
            case PresetID.kitchenNeon: return PresetID.haccpRed
            case PresetID.cleanWhite: return PresetID.minimalWhite
            default: return id
            }
        }()
        return allPresets.first(where: { $0.id == migrated }) ?? defaultPreset
    }

    // MARK: Preset definitions

    static let darkPremium = AppTheme(
        id: PresetID.darkPremium,
        name: "Dark Premium",
        descriptionText: "Nero profondo, rosso HACCP premium e profondità enterprise.",
        isLight: false,
        backgroundHex:        "#0A0A0A",
        backgroundEndHex:     "#141414",
        surfaceHex:           "#141414",
        surfaceElevatedHex:   "#1E1E1E",
        dividerHex:           "#2A2A2A",
        primaryHex:           "#FF4D4D",
        accentHex:            "#FF6B6B",
        secondaryHex:         "#5B8DEF",
        textPrimaryHex:       "#F5F5F5",
        textSecondaryHex:     "#A3A3A3",
        textOnPrimaryHex:     "#FFFFFF",
        successHex:           "#34C759",
        warningHex:           "#FF9F43",
        errorHex:             "#FF4D4D",
        infoHex:              "#5AC8FA",
        borderHex:            "#333333",
        glowAccentHex:        "#FF4D4D",
        defaultDashboardStyle: .enterprise,
        defaultSidebarStyle:   .floating,
        defaultBackgroundStyle: .gradient,
        cornerRadiusBase: 18,
        prefersDarkColorScheme: true
    )

    static let lightPremium = AppTheme(
        id: PresetID.lightPremium,
        name: "Light Premium",
        descriptionText: "Bianco caldo, rosso elegante — ideale in cucina illuminata.",
        isLight: true,
        backgroundHex:        "#F5F5F5",
        backgroundEndHex:     "#FFFFFF",
        surfaceHex:           "#FFFFFF",
        surfaceElevatedHex:   "#FAFAFA",
        dividerHex:           "#E5E5E5",
        primaryHex:           "#FF4D4D",
        accentHex:            "#E63946",
        secondaryHex:         "#2563EB",
        textPrimaryHex:       "#0A0A0A",
        textSecondaryHex:     "#525252",
        textOnPrimaryHex:     "#FFFFFF",
        successHex:           "#16A34A",
        warningHex:           "#EA580C",
        errorHex:             "#DC2626",
        infoHex:              "#2563EB",
        borderHex:            "#E0E0E0",
        glowAccentHex:        nil,
        defaultDashboardStyle: .cardsClassic,
        defaultSidebarStyle:   .blur,
        defaultBackgroundStyle: .minimal,
        cornerRadiusBase: 16,
        prefersDarkColorScheme: false
    )

    static let midnight = AppTheme(
        id: PresetID.midnight,
        name: "Midnight",
        descriptionText: "Blu notte e ciano luminoso. Eleganza serale.",
        isLight: false,
        backgroundHex:        "#0B1220",
        backgroundEndHex:     "#11203A",
        surfaceHex:           "#152038",
        surfaceElevatedHex:   "#1B2B49",
        dividerHex:           "#23375F",
        primaryHex:           "#3FA9F5",
        accentHex:            "#00E5FF",
        secondaryHex:         "#9381FF",
        textPrimaryHex:       "#E6F0FA",
        textSecondaryHex:     "#9FB3C8",
        textOnPrimaryHex:     "#0B1220",
        successHex:           "#34D399",
        warningHex:           "#FBBF24",
        errorHex:             "#F87171",
        infoHex:              "#7DD3FC",
        borderHex:            "#1F2E4F",
        glowAccentHex:        "#00E5FF",
        defaultDashboardStyle: .glassmorphism,
        defaultSidebarStyle:   .blur,
        defaultBackgroundStyle: .gradient,
        cornerRadiusBase: 18,
        prefersDarkColorScheme: true
    )

    static let haccpRed = AppTheme(
        id: PresetID.haccpRed,
        name: "HACCP Red",
        descriptionText: "Rosso brand dominante, nero profondo — identità HACCP forte.",
        isLight: false,
        backgroundHex:        "#0A0A0A",
        backgroundEndHex:     "#1A0505",
        surfaceHex:           "#141010",
        surfaceElevatedHex:   "#1E1414",
        dividerHex:           "#3D2020",
        primaryHex:           "#FF4D4D",
        accentHex:            "#FF8080",
        secondaryHex:         "#C41E2A",
        textPrimaryHex:       "#F5F5F5",
        textSecondaryHex:     "#B3A3A3",
        textOnPrimaryHex:     "#FFFFFF",
        successHex:           "#34C759",
        warningHex:           "#FF9F43",
        errorHex:             "#FF4D4D",
        infoHex:              "#5AC8FA",
        borderHex:            "#4D2828",
        glowAccentHex:        "#FF4D4D",
        defaultDashboardStyle: .modernNeon,
        defaultSidebarStyle:   .floating,
        defaultBackgroundStyle: .gradient,
        cornerRadiusBase: 16,
        prefersDarkColorScheme: true
    )

    static let minimalWhite = AppTheme(
        id: PresetID.minimalWhite,
        name: "Minimal White",
        descriptionText: "Ultra minimal bianco puro. Look studio HACCP, asciutto e netto.",
        isLight: true,
        backgroundHex:        "#FFFFFF",
        backgroundEndHex:     "#FAFAFA",
        surfaceHex:           "#FFFFFF",
        surfaceElevatedHex:   "#FFFFFF",
        dividerHex:           "#EEEEEE",
        primaryHex:           "#111827",
        accentHex:            "#6B7280",
        secondaryHex:         "#374151",
        textPrimaryHex:       "#0F172A",
        textSecondaryHex:     "#475569",
        textOnPrimaryHex:     "#FFFFFF",
        successHex:           "#16A34A",
        warningHex:           "#CA8A04",
        errorHex:             "#DC2626",
        infoHex:              "#2563EB",
        borderHex:            "#E5E7EB",
        glowAccentHex:        nil,
        defaultDashboardStyle: .minimalFlat,
        defaultSidebarStyle:   .compact,
        defaultBackgroundStyle: .solid,
        cornerRadiusBase: 12,
        prefersDarkColorScheme: false
    )

    // Alias legacy (compatibilità codice interno)
    static var haccpDarkPro: AppTheme { darkPremium }
    static var haccpLightPro: AppTheme { lightPremium }
    static var midnightBlue: AppTheme { midnight }
    static var kitchenNeon: AppTheme { haccpRed }
    static var cleanWhite: AppTheme { minimalWhite }
}
