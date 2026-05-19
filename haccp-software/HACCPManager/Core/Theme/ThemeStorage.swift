//
//  ThemeStorage.swift
//  HACCP Manager — Mirror UserDefaults per bootstrap sincrono pre-SwiftData.
//

import Foundation

@MainActor
final class ThemeStorage {

    static let shared = ThemeStorage()

    private enum Keys {
        static let themePresetID    = "haccp.theme.presetID"
        static let layoutMode       = "haccp.theme.layoutMode"
        static let dashboardStyle   = "haccp.theme.dashboardStyle"
        static let sidebarStyle     = "haccp.theme.sidebarStyle"
        static let backgroundStyle  = "haccp.theme.backgroundStyle"
        static let animationLevel   = "haccp.theme.animationLevel"
        static let followsSystem    = "haccp.theme.followsSystem"
        static let highContrast     = "haccp.theme.highContrast"
        static let kitchenMode      = "haccp.theme.kitchenMode"
        static let textSizeModifier = "haccp.theme.textSizeModifier"
        static let animationsOn     = "haccp.theme.animationsOn"
        static let reduceMotion     = "haccp.theme.reduceMotion"
        static let reduceGraphics   = "haccp.theme.reduceGraphics"
        static let didSeedDefaults  = "haccp.theme.didSeedDefaults"
    }

    private let defaults = UserDefaults.standard

    private init() {}

    var hasPersistedAppearance: Bool {
        defaults.bool(forKey: Keys.didSeedDefaults)
            || defaults.string(forKey: Keys.themePresetID) != nil
    }

    /// Lettura sincrona all'avvio — prima del primo frame SwiftUI.
    func restoreAppearance() -> AppearanceSettings {
        var settings = AppearanceSettings()

        if let id = defaults.string(forKey: Keys.themePresetID), !id.isEmpty {
            settings.themePresetID = id
        }

        if defaults.object(forKey: Keys.layoutMode) != nil {
            settings.layoutModeRaw = defaults.integer(forKey: Keys.layoutMode)
        }
        if defaults.object(forKey: Keys.dashboardStyle) != nil {
            settings.dashboardStyleRaw = defaults.integer(forKey: Keys.dashboardStyle)
        }
        if defaults.object(forKey: Keys.sidebarStyle) != nil {
            settings.sidebarStyleRaw = defaults.integer(forKey: Keys.sidebarStyle)
        }
        if defaults.object(forKey: Keys.backgroundStyle) != nil {
            settings.backgroundStyleRaw = defaults.integer(forKey: Keys.backgroundStyle)
        }
        if defaults.object(forKey: Keys.animationLevel) != nil {
            settings.animationLevelRaw = defaults.integer(forKey: Keys.animationLevel)
        }
        if defaults.object(forKey: Keys.followsSystem) != nil {
            settings.followsSystemAppearance = defaults.bool(forKey: Keys.followsSystem)
        }
        if defaults.object(forKey: Keys.highContrast) != nil {
            settings.highContrast = defaults.bool(forKey: Keys.highContrast)
        }
        if defaults.object(forKey: Keys.kitchenMode) != nil {
            settings.kitchenMode = defaults.bool(forKey: Keys.kitchenMode)
        }
        if defaults.object(forKey: Keys.textSizeModifier) != nil {
            settings.textSizeModifier = defaults.double(forKey: Keys.textSizeModifier)
        }
        if defaults.object(forKey: Keys.animationsOn) != nil {
            settings.animationsEnabled = defaults.bool(forKey: Keys.animationsOn)
        }
        if defaults.object(forKey: Keys.reduceMotion) != nil {
            settings.reduceMotion = defaults.bool(forKey: Keys.reduceMotion)
        }
        if defaults.object(forKey: Keys.reduceGraphics) != nil {
            settings.reduceGraphicsEffects = defaults.bool(forKey: Keys.reduceGraphics)
        }

        settings.normalizeStoredPreferences()
        return settings
    }

    func mirror(_ appearance: AppearanceSettings) {
        defaults.set(appearance.themePresetID, forKey: Keys.themePresetID)
        defaults.set(appearance.layoutModeRaw, forKey: Keys.layoutMode)
        defaults.set(appearance.dashboardStyleRaw, forKey: Keys.dashboardStyle)
        defaults.set(appearance.sidebarStyleRaw, forKey: Keys.sidebarStyle)
        defaults.set(appearance.backgroundStyleRaw, forKey: Keys.backgroundStyle)
        defaults.set(appearance.animationLevelRaw, forKey: Keys.animationLevel)
        defaults.set(appearance.followsSystemAppearance, forKey: Keys.followsSystem)
        defaults.set(appearance.highContrast, forKey: Keys.highContrast)
        defaults.set(appearance.kitchenMode, forKey: Keys.kitchenMode)
        defaults.set(appearance.textSizeModifier, forKey: Keys.textSizeModifier)
        defaults.set(appearance.animationsEnabled, forKey: Keys.animationsOn)
        defaults.set(appearance.reduceMotion, forKey: Keys.reduceMotion)
        defaults.set(appearance.reduceGraphicsEffects, forKey: Keys.reduceGraphics)
        defaults.set(true, forKey: Keys.didSeedDefaults)
    }

    // MARK: Legacy bootstrap helpers

    func bootstrapTheme() -> AppTheme {
        AppTheme.preset(forID: defaults.string(forKey: Keys.themePresetID) ?? "")
    }
}
