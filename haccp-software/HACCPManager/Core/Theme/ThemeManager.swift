//
//  ThemeManager.swift
//  HACCP Manager — Theme System
//
//  Facade globale @Observable. Le views leggono `ThemeManager.shared.*`
//  oppure (preferibile) ricevono il manager via Environment.
//
//  Mantiene compatibilità con la vecchia API (primary/accent/background/
//  surface/text/textSecondary/cornerRadius/spring/...) per non rompere
//  le ~40 views che già la usano.
//

import SwiftUI
import Observation

@Observable
public class ThemeManager {

    public static let shared = ThemeManager()

    public init() {}

    // MARK: Source of truth

    /// Reactive: legge sempre lo storage globale, così SwiftUI propaga gli update.
    public var appearance: AppearanceSettings {
        SettingsStorageService.shared.appearance
    }

    // MARK: Resolved values (drive l'intera UI)

    /// Tema preset corrente (HACCP Dark Pro, Midnight Blue, ...).
    var currentTheme: AppTheme { appearance.resolvedTheme }

    /// Layout mode corrente.
    var layoutMode: LayoutMode { appearance.layoutMode }

    /// Dashboard style corrente (override utente o default del preset).
    var dashboardStyle: DashboardStyle { appearance.resolvedDashboardStyle }

    /// Sidebar style corrente.
    var sidebarStyle: SidebarStyle { appearance.resolvedSidebarStyle }

    /// Background style corrente.
    var backgroundStyle: BackgroundStyle { appearance.resolvedBackgroundStyle }

    /// Animation level corrente (effettivo: collassato a .none se reduceMotion).
    var animationLevel: AnimationLevel {
        if appearance.reduceMotion { return .none }
        if !appearance.animationsEnabled { return .none }
        return appearance.animationLevel
    }

    /// Tokens semantici.
    var typography: ThemeTypography {
        ThemeTypography(
            sizeMultiplier: appearance.textSizeModifier,
            layoutMode: layoutMode
        )
    }

    var spacing: ThemeSpacing {
        ThemeSpacing(
            layoutMode: layoutMode,
            cornerBase: currentTheme.cornerRadiusBase
        )
    }

    var motion: ThemeAnimation { ThemeAnimation(level: animationLevel) }

    // MARK: Semantic colors (preferred API)

    var colorBackground: Color {
        appearance.followsSystemAppearance ? Color(.systemBackground) : currentTheme.background
    }

    var colorBackgroundEnd: Color? { currentTheme.backgroundEnd }

    var colorSurface: Color {
        appearance.followsSystemAppearance ? Color(.secondarySystemBackground) : currentTheme.surface
    }

    var colorSurfaceElevated: Color {
        appearance.followsSystemAppearance ? Color(.tertiarySystemBackground) : currentTheme.surfaceElevated
    }

    var colorPrimary: Color   { currentTheme.primary }
    var colorAccent: Color    { currentTheme.accent }
    var colorSecondary: Color { currentTheme.secondary }

    var colorTextPrimary: Color {
        appearance.followsSystemAppearance
            ? Color(.label)
            : ThemeContrast.textPrimary(in: currentTheme, highContrast: appearance.highContrast)
    }

    var colorTextSecondary: Color {
        appearance.followsSystemAppearance
            ? Color(.secondaryLabel)
            : ThemeContrast.textSecondary(in: currentTheme, highContrast: appearance.highContrast)
    }

    var colorTextOnPrimary: Color { currentTheme.textOnPrimary }
    var colorDivider: Color {
        ThemeContrast.divider(in: currentTheme, highContrast: appearance.highContrast)
    }
    var colorSuccess: Color { currentTheme.success }
    var colorWarning: Color { currentTheme.warning }
    var colorError:   Color { currentTheme.error }
    var colorInfo:    Color { currentTheme.info }
    var colorBorder:  Color { currentTheme.border }
    var colorGlow:    Color? { currentTheme.glow }

    // MARK: Color scheme + dark detection

    public var preferredColorScheme: ColorScheme? {
        if appearance.followsSystemAppearance { return nil }
        return currentTheme.prefersDarkColorScheme ? .dark : .light
    }

    public var isDark: Bool {
        if appearance.followsSystemAppearance {
            return UITraitCollection.current.userInterfaceStyle == .dark
        }
        return currentTheme.prefersDarkColorScheme
    }

    // MARK: Mutations (drive UI live)

    @MainActor
    func selectPreset(_ preset: AppTheme) {
        let storage = SettingsStorageService.shared
        guard storage.appearance.themePresetID != preset.id else { return }
        storage.appearance.themePresetID = preset.id
        storage.appearance.theme = preset.isLight
            ? AppThemeOption.light.rawValue
            : AppThemeOption.dark.rawValue
        // Reset overrides quando si cambia preset (i default del preset prevalgono).
        storage.appearance.dashboardStyleRaw = -1
        storage.appearance.sidebarStyleRaw = -1
        storage.appearance.backgroundStyleRaw = -1
        storage.appearance.followsSystemAppearance = false
        storage.saveAll()
        ThemeStorage.shared.mirror(storage.appearance)
    }

    @MainActor
    func setLayoutMode(_ mode: LayoutMode) {
        let storage = SettingsStorageService.shared
        guard storage.appearance.layoutMode != mode else { return }
        storage.appearance.layoutMode = mode
        storage.saveAll()
        ThemeStorage.shared.mirror(storage.appearance)
    }

    @MainActor
    func setDashboardStyle(_ style: DashboardStyle?) {
        let storage = SettingsStorageService.shared
        let newRaw = style?.rawValue ?? -1
        guard storage.appearance.dashboardStyleRaw != newRaw else { return }
        storage.appearance.dashboardStyleRaw = newRaw
        storage.saveAll()
        ThemeStorage.shared.mirror(storage.appearance)
    }

    @MainActor
    func setSidebarStyle(_ style: SidebarStyle?) {
        let storage = SettingsStorageService.shared
        let newRaw = style?.rawValue ?? -1
        guard storage.appearance.sidebarStyleRaw != newRaw else { return }
        storage.appearance.sidebarStyleRaw = newRaw
        storage.saveAll()
        ThemeStorage.shared.mirror(storage.appearance)
    }

    @MainActor
    func setBackgroundStyle(_ style: BackgroundStyle?) {
        let storage = SettingsStorageService.shared
        let newRaw = style?.rawValue ?? -1
        guard storage.appearance.backgroundStyleRaw != newRaw else { return }
        storage.appearance.backgroundStyleRaw = newRaw
        storage.saveAll()
        ThemeStorage.shared.mirror(storage.appearance)
    }

    @MainActor
    func setAnimationLevel(_ level: AnimationLevel) {
        let storage = SettingsStorageService.shared
        guard storage.appearance.animationLevel != level else { return }
        storage.appearance.animationLevel = level
        storage.appearance.animationsEnabled = level != .none
        storage.saveAll()
        ThemeStorage.shared.mirror(storage.appearance)
    }

    @MainActor
    func setFollowsSystem(_ on: Bool) {
        let storage = SettingsStorageService.shared
        guard storage.appearance.followsSystemAppearance != on else { return }
        storage.appearance.followsSystemAppearance = on
        storage.saveAll()
        ThemeStorage.shared.mirror(storage.appearance)
    }

    @MainActor
    func setHighContrast(_ on: Bool) {
        let storage = SettingsStorageService.shared
        guard storage.appearance.highContrast != on else { return }
        storage.appearance.highContrast = on
        storage.saveAll()
        ThemeStorage.shared.mirror(storage.appearance)
    }

    @MainActor
    func setTextSize(_ value: Double) {
        let storage = SettingsStorageService.shared
        let clamped = max(0.8, min(1.5, value))
        guard storage.appearance.textSizeModifier != clamped else { return }
        storage.appearance.textSizeModifier = clamped
        storage.saveAll()
        ThemeStorage.shared.mirror(storage.appearance)
    }

    @MainActor
    func setKitchenMode(_ on: Bool) {
        let storage = SettingsStorageService.shared
        guard storage.appearance.kitchenMode != on else { return }
        storage.appearance.kitchenMode = on
        if on {
            // Kitchen Mode preset: largeTouch + Kitchen Neon + high contrast + animazioni ridotte.
            storage.appearance.themePresetID = AppTheme.PresetID.kitchenNeon
            storage.appearance.theme = AppThemeOption.dark.rawValue
            storage.appearance.layoutModeRaw = LayoutMode.largeTouch.rawValue
            storage.appearance.highContrast = true
            storage.appearance.animationLevelRaw = AnimationLevel.reduced.rawValue
            storage.appearance.dashboardStyleRaw = -1
            storage.appearance.sidebarStyleRaw = -1
            storage.appearance.backgroundStyleRaw = -1
            storage.appearance.followsSystemAppearance = false
            storage.appearance.textSizeModifier = max(storage.appearance.textSizeModifier, 1.15)
        }
        storage.saveAll()
        ThemeStorage.shared.mirror(storage.appearance)
    }

    @MainActor
    func setReduceMotion(_ on: Bool) {
        let storage = SettingsStorageService.shared
        guard storage.appearance.reduceMotion != on else { return }
        storage.appearance.reduceMotion = on
        storage.saveAll()
        ThemeStorage.shared.mirror(storage.appearance)
    }

    @MainActor
    func setReduceGraphics(_ on: Bool) {
        let storage = SettingsStorageService.shared
        guard storage.appearance.reduceGraphicsEffects != on else { return }
        storage.appearance.reduceGraphicsEffects = on
        storage.saveAll()
        ThemeStorage.shared.mirror(storage.appearance)
    }

    /// Reset completo ai default del preset corrente.
    @MainActor
    func resetToPresetDefaults() {
        let storage = SettingsStorageService.shared
        storage.appearance.dashboardStyleRaw = -1
        storage.appearance.sidebarStyleRaw = -1
        storage.appearance.backgroundStyleRaw = -1
        storage.saveAll()
        ThemeStorage.shared.mirror(storage.appearance)
    }

    // MARK: ----- BACKWARD COMPATIBILITY (vecchia API ThemeManager) -----
    // Le views esistenti chiamano `theme.primary`, `theme.background`, ecc.
    // Manteniamo questi alias mappati sul nuovo sistema.

    public var primary: Color   { colorPrimary }
    public var accent: Color    { colorAccent }
    public var background: Color  { colorBackground }
    public var surface: Color     { colorSurface }
    public var text: Color        { colorTextPrimary }
    public var textSecondary: Color { colorTextSecondary }

    public var cornerRadius: CGFloat { spacing.cornerLarge }

    public var buttonPadding: CGFloat {
        appearance.kitchenMode ? spacing.xl : spacing.lg
    }

    public var fontSizeBase: CGFloat {
        16 * appearance.textSizeModifier
    }

    public var spring: Animation     { motion.standard ?? .linear(duration: 0.001) }
    public var slowSpring: Animation { motion.slow     ?? .linear(duration: 0.001) }
    public var fastEase: Animation   { motion.fast     ?? .linear(duration: 0.001) }

    /// LEGACY (Light/Dark/System Picker) — mantenuto per i settings vecchio stile.
    public var themeOption: AppThemeOption { appearance.themeOption }

    @MainActor
    public func setTheme(_ option: AppThemeOption) {
        let storage = SettingsStorageService.shared
        guard storage.appearance.themeOption != option else { return }
        storage.appearance.themeOption = option
        // Allinea preset al cambio Light/Dark/System del Picker classico.
        switch option {
        case .dark:
            storage.appearance.themePresetID = AppTheme.PresetID.haccpDarkPro
            storage.appearance.followsSystemAppearance = false
        case .light:
            storage.appearance.themePresetID = AppTheme.PresetID.haccpLightPro
            storage.appearance.followsSystemAppearance = false
        case .system:
            storage.appearance.followsSystemAppearance = true
        }
        storage.saveAll()
        ThemeStorage.shared.mirror(storage.appearance)
    }
}
