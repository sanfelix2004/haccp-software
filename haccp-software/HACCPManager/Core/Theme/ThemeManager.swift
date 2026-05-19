//
//  ThemeManager.swift
//  HACCP Manager — Theme System
//

import SwiftUI
import Observation

@Observable
public class ThemeManager {

    public static let shared: ThemeManager = {
        let manager = ThemeManager()
        manager.loadSavedTheme()
        return manager
    }()

    /// Incrementato a ogni caricamento/salvataggio tema — forza refresh SwiftUI.
    private(set) var appearanceRevision: Int = 0

    public init() {}

    /// Bootstrap sincrono: UserDefaults → poi SwiftData in `SettingsStorageService.setup`.
    @MainActor
    public func loadSavedTheme() {
        SettingsStorageService.shared.bootstrapAppearanceFromDisk()
        bumpAppearanceRevision()
    }

    @MainActor
    public func bumpAppearanceRevision() {
        appearanceRevision += 1
    }

    public var appearance: AppearanceSettings {
        SettingsStorageService.shared.appearance
    }

    var currentTheme: AppTheme { appearance.resolvedTheme }

    var layoutMode: LayoutMode { appearance.resolvedLayoutMode }
    var dashboardStyle: DashboardStyle { appearance.resolvedDashboardStyle }
    var sidebarStyle: SidebarStyle { appearance.resolvedSidebarStyle }
    var backgroundStyle: BackgroundStyle { appearance.resolvedBackgroundStyle }

    var animationLevel: AnimationLevel {
        if appearance.reduceMotion { return .none }
        if !appearance.animationsEnabled { return .none }
        return appearance.animationLevel
    }

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

    var colorBackground: Color { currentTheme.background }
    var colorBackgroundEnd: Color? { currentTheme.backgroundEnd }
    var colorSurface: Color { currentTheme.surface }
    var colorSurfaceElevated: Color { currentTheme.surfaceElevated }
    var colorPrimary: Color { currentTheme.primary }
    var colorAccent: Color { currentTheme.accent }
    var colorSecondary: Color { currentTheme.secondary }

    var colorTextPrimary: Color {
        ThemeContrast.textPrimary(in: currentTheme, highContrast: appearance.highContrast)
    }

    var colorTextSecondary: Color {
        ThemeContrast.textSecondary(in: currentTheme, highContrast: appearance.highContrast)
    }

    var colorTextOnPrimary: Color { currentTheme.textOnPrimary }
    var colorDivider: Color {
        ThemeContrast.divider(in: currentTheme, highContrast: appearance.highContrast)
    }
    var colorSuccess: Color { currentTheme.success }
    var colorWarning: Color { currentTheme.warning }
    var colorError: Color { currentTheme.error }
    var colorInfo: Color { currentTheme.info }
    var colorBorder: Color { currentTheme.border }
    var colorGlow: Color? { currentTheme.glow }

    /// Velo modale / overlay (leggero su tema chiaro, più scuro su dark).
    var colorScrim: Color {
        isDark ? Color.black.opacity(0.72) : Color.black.opacity(0.38)
    }

    /// Sfondo area anteprima fotocamera (non usare nero pieno su tema chiaro).
    var colorCameraPreviewBackground: Color { colorSurfaceElevated }

    public var preferredColorScheme: ColorScheme? {
        if appearance.followsSystemAppearance { return nil }
        return currentTheme.prefersDarkColorScheme ? .dark : .light
    }

    public var isDark: Bool { !currentTheme.isLight }

    // MARK: Mutations

    @MainActor
    func selectPreset(_ preset: AppTheme) {
        let storage = SettingsStorageService.shared
        storage.appearance.themePresetID = preset.id
        storage.appearance.dashboardStyleRaw = -1
        storage.appearance.sidebarStyleRaw = -1
        storage.appearance.backgroundStyleRaw = -1
        storage.saveAll()
        bumpAppearanceRevision()
    }

    @MainActor
    func setLayoutMode(_ mode: LayoutMode) {
        let storage = SettingsStorageService.shared
        guard !storage.appearance.kitchenMode else { return }
        storage.appearance.layoutMode = mode
        storage.saveAll()
        bumpAppearanceRevision()
    }

    @MainActor
    func setDashboardStyle(_ style: DashboardStyle?) {
        let storage = SettingsStorageService.shared
        storage.appearance.dashboardStyleRaw = style?.rawValue ?? -1
        storage.saveAll()
        bumpAppearanceRevision()
    }

    @MainActor
    func setSidebarStyle(_ style: SidebarStyle?) {
        let storage = SettingsStorageService.shared
        storage.appearance.sidebarStyleRaw = style?.rawValue ?? -1
        storage.saveAll()
        bumpAppearanceRevision()
    }

    @MainActor
    func setBackgroundStyle(_ style: BackgroundStyle?) {
        let storage = SettingsStorageService.shared
        storage.appearance.backgroundStyleRaw = style?.rawValue ?? -1
        storage.saveAll()
        bumpAppearanceRevision()
    }

    @MainActor
    func normalizeAppearance() {
        let storage = SettingsStorageService.shared
        storage.appearance.normalizeStoredPreferences()
        storage.saveAll()
        bumpAppearanceRevision()
    }

    @MainActor
    func setAnimationLevel(_ level: AnimationLevel) {
        let storage = SettingsStorageService.shared
        guard storage.appearance.animationLevel != level else { return }
        storage.appearance.animationLevel = level
        storage.appearance.animationsEnabled = level != .none
        storage.saveAll()
        bumpAppearanceRevision()
    }

    @MainActor
    func setFollowsSystem(_ on: Bool) {
        let storage = SettingsStorageService.shared
        storage.appearance.followsSystemAppearance = on
        storage.saveAll()
        bumpAppearanceRevision()
    }

    @MainActor
    func setHighContrast(_ on: Bool) {
        let storage = SettingsStorageService.shared
        guard storage.appearance.highContrast != on else { return }
        storage.appearance.highContrast = on
        storage.saveAll()
        bumpAppearanceRevision()
    }

    @MainActor
    func setTextSize(_ value: Double) {
        let storage = SettingsStorageService.shared
        let clamped = max(0.85, min(1.4, value))
        guard storage.appearance.textSizeModifier != clamped else { return }
        storage.appearance.textSizeModifier = clamped
        storage.saveAll()
        bumpAppearanceRevision()
    }

    @MainActor
    func setKitchenMode(_ on: Bool) {
        let storage = SettingsStorageService.shared
        guard storage.appearance.kitchenMode != on else { return }
        storage.appearance.kitchenMode = on
        if on {
            storage.appearance.layoutModeRaw = LayoutMode.largeTouch.rawValue
            storage.appearance.highContrast = true
            storage.appearance.animationLevelRaw = AnimationLevel.reduced.rawValue
            storage.appearance.textSizeModifier = max(storage.appearance.textSizeModifier, 1.12)
        } else {
            storage.appearance.highContrast = false
        }
        storage.saveAll()
        bumpAppearanceRevision()
    }

    @MainActor
    func setReduceMotion(_ on: Bool) {
        let storage = SettingsStorageService.shared
        guard storage.appearance.reduceMotion != on else { return }
        storage.appearance.reduceMotion = on
        storage.saveAll()
        bumpAppearanceRevision()
    }

    @MainActor
    func setReduceGraphics(_ on: Bool) {
        let storage = SettingsStorageService.shared
        guard storage.appearance.reduceGraphicsEffects != on else { return }
        storage.appearance.reduceGraphicsEffects = on
        storage.saveAll()
        bumpAppearanceRevision()
    }

    @MainActor
    func resetToPresetDefaults() {
        selectPreset(currentTheme)
    }

    // MARK: Legacy API

    public var primary: Color { colorPrimary }
    public var accent: Color { colorAccent }
    public var background: Color { colorBackground }
    public var surface: Color { colorSurface }
    public var text: Color { colorTextPrimary }
    public var textSecondary: Color { colorTextSecondary }
    public var cornerRadius: CGFloat { spacing.cornerLarge }

    public var buttonPadding: CGFloat {
        appearance.kitchenMode ? spacing.xl : spacing.lg
    }

    public var fontSizeBase: CGFloat {
        18 * appearance.textSizeModifier
    }

    public var spring: Animation { motion.standard ?? .linear(duration: 0.001) }
    public var slowSpring: Animation { motion.slow ?? .linear(duration: 0.001) }
    public var fastEase: Animation { motion.fast ?? .linear(duration: 0.001) }

    public var themeOption: AppThemeOption {
        currentTheme.prefersDarkColorScheme ? .dark : .light
    }

    @MainActor
    public func setTheme(_ option: AppThemeOption) {
        let storage = SettingsStorageService.shared
        storage.appearance.themeOption = option
        switch option {
        case .dark: selectPreset(.darkPremium)
        case .light: selectPreset(.lightPremium)
        case .system:
            storage.appearance.followsSystemAppearance = true
            storage.saveAll()
            bumpAppearanceRevision()
        }
    }

    @MainActor
    func enforceBrandAppearance() {
        normalizeAppearance()
    }
}
