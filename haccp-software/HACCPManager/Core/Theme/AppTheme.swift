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
        static let haccpDarkPro  = "haccp_dark_pro"
        static let haccpLightPro = "haccp_light_pro"
        static let midnightBlue  = "midnight_blue"
        static let graphite      = "graphite"
        static let kitchenNeon   = "kitchen_neon"
        static let cleanWhite    = "clean_white"
    }

    /// Tutti i preset esposti all'utente.
    static let allPresets: [AppTheme] = [
        .haccpDarkPro,
        .haccpLightPro,
        .midnightBlue,
        .graphite,
        .kitchenNeon,
        .cleanWhite
    ]

    /// Preset di default in caso di prima esecuzione o ID non riconosciuto.
    static let defaultPreset: AppTheme = .haccpDarkPro

    static func preset(forID id: String) -> AppTheme {
        allPresets.first(where: { $0.id == id }) ?? defaultPreset
    }

    // MARK: Preset definitions

    static let haccpDarkPro = AppTheme(
        id: PresetID.haccpDarkPro,
        name: "HACCP Dark Pro",
        descriptionText: "Nero profondo, rosso brand HACCP e vetro blur premium.",
        isLight: false,
        backgroundHex:        "#0A0A0A",
        backgroundEndHex:     "#141414",
        surfaceHex:           "#161616",
        surfaceElevatedHex:   "#1F1F1F",
        dividerHex:           "#2A2A2A",
        primaryHex:           "#E63946",
        accentHex:            "#FFD700",
        secondaryHex:         "#3A86FF",
        textPrimaryHex:       "#FFFFFF",
        textSecondaryHex:     "#9CA3AF",
        textOnPrimaryHex:     "#FFFFFF",
        successHex:           "#34C759",
        warningHex:           "#FFCC00",
        errorHex:             "#FF3B30",
        infoHex:              "#5AC8FA",
        borderHex:            "#2D2D2D",
        glowAccentHex:        nil,
        defaultDashboardStyle: .cardsClassic,
        defaultSidebarStyle:   .full,
        defaultBackgroundStyle: .gradient,
        cornerRadiusBase: 16,
        prefersDarkColorScheme: true
    )

    static let haccpLightPro = AppTheme(
        id: PresetID.haccpLightPro,
        name: "HACCP Light Pro",
        descriptionText: "Bianco e grigio chiaro con accenti rosso HACCP. Look pulito.",
        isLight: true,
        backgroundHex:        "#F5F5F7",
        backgroundEndHex:     "#FFFFFF",
        surfaceHex:           "#FFFFFF",
        surfaceElevatedHex:   "#FFFFFF",
        dividerHex:           "#E5E5EA",
        primaryHex:           "#D62828",
        accentHex:            "#B7791F",
        secondaryHex:         "#0A66C2",
        textPrimaryHex:       "#11181C",
        textSecondaryHex:     "#6B7280",
        textOnPrimaryHex:     "#FFFFFF",
        successHex:           "#1F8A4C",
        warningHex:           "#B45309",
        errorHex:             "#B91C1C",
        infoHex:              "#0A66C2",
        borderHex:            "#D1D5DB",
        glowAccentHex:        nil,
        defaultDashboardStyle: .cardsClassic,
        defaultSidebarStyle:   .full,
        defaultBackgroundStyle: .minimal,
        cornerRadiusBase: 14,
        prefersDarkColorScheme: false
    )

    static let midnightBlue = AppTheme(
        id: PresetID.midnightBlue,
        name: "Midnight Blue",
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

    static let graphite = AppTheme(
        id: PresetID.graphite,
        name: "Graphite",
        descriptionText: "Grigio carbone, sobrio ed enterprise. Massima leggibilità.",
        isLight: false,
        backgroundHex:        "#1C1C1E",
        backgroundEndHex:     "#2C2C2E",
        surfaceHex:           "#2C2C2E",
        surfaceElevatedHex:   "#3A3A3C",
        dividerHex:           "#48484A",
        primaryHex:           "#8E8E93",
        accentHex:            "#FFFFFF",
        secondaryHex:         "#AEAEB2",
        textPrimaryHex:       "#F2F2F7",
        textSecondaryHex:     "#C7C7CC",
        textOnPrimaryHex:     "#1C1C1E",
        successHex:           "#30D158",
        warningHex:           "#FFD60A",
        errorHex:             "#FF453A",
        infoHex:              "#64D2FF",
        borderHex:            "#48484A",
        glowAccentHex:        nil,
        defaultDashboardStyle: .enterprise,
        defaultSidebarStyle:   .solid,
        defaultBackgroundStyle: .solid,
        cornerRadiusBase: 10,
        prefersDarkColorScheme: true
    )

    static let kitchenNeon = AppTheme(
        id: PresetID.kitchenNeon,
        name: "Kitchen Neon",
        descriptionText: "Nero assoluto con rosso acceso e glow neon. High-tech.",
        isLight: false,
        backgroundHex:        "#000000",
        backgroundEndHex:     "#0D0306",
        surfaceHex:           "#0F0F12",
        surfaceElevatedHex:   "#16161B",
        dividerHex:           "#2A1014",
        primaryHex:           "#FF1744",
        accentHex:            "#FF4081",
        secondaryHex:         "#00E5FF",
        textPrimaryHex:       "#FFFFFF",
        textSecondaryHex:     "#A1A1AA",
        textOnPrimaryHex:     "#FFFFFF",
        successHex:           "#39FF14",
        warningHex:           "#FFEA00",
        errorHex:             "#FF1744",
        infoHex:              "#00E5FF",
        borderHex:            "#FF174433",
        glowAccentHex:        "#FF1744",
        defaultDashboardStyle: .modernNeon,
        defaultSidebarStyle:   .floating,
        defaultBackgroundStyle: .animated,
        cornerRadiusBase: 14,
        prefersDarkColorScheme: true
    )

    static let cleanWhite = AppTheme(
        id: PresetID.cleanWhite,
        name: "Clean White",
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
        cornerRadiusBase: 8,
        prefersDarkColorScheme: false
    )
}
