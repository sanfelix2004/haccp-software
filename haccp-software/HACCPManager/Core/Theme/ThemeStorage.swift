//
//  ThemeStorage.swift
//  HACCP Manager — Theme System
//
//  Adattatore di persistenza per il sistema temi. Delegate a
//  `SettingsStorageService` (single source of truth, già persistente in SwiftData)
//  e aggiunge mirror su UserDefaults per accesso early-startup (es. splash).
//

import Foundation
import SwiftUI

/// Persistenza del Theme. Pensato per essere usato SOLO dal `ThemeManager`.
/// Le views devono leggere/scrivere tramite `ThemeManager` o le `AppearanceSettings`.
@MainActor
final class ThemeStorage {

    static let shared = ThemeStorage()

    // Chiavi UserDefaults per quick-read (es. splash screen, prima della SwiftData hydration).
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
    }

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: Read (early bootstrap)

    /// Theme inferito dall'ultima sessione, leggibile sincronamente.
    /// Utile per evitare il "flash" all'avvio prima che SwiftData carichi.
    func bootstrapTheme() -> AppTheme {
        let id = defaults.string(forKey: Keys.themePresetID) ?? ""
        return id.isEmpty ? .haccpDarkPro : AppTheme.preset(forID: id)
    }

    func bootstrapLayoutMode() -> LayoutMode {
        let raw = defaults.object(forKey: Keys.layoutMode) as? Int
            ?? LayoutMode.comfortable.rawValue
        return LayoutMode(rawValue: raw) ?? .comfortable
    }

    func bootstrapAnimationLevel() -> AnimationLevel {
        let raw = defaults.object(forKey: Keys.animationLevel) as? Int
            ?? AnimationLevel.full.rawValue
        return AnimationLevel(rawValue: raw) ?? .full
    }

    // MARK: Mirror dei valori (chiamato da `ThemeManager` dopo ogni save).

    func mirror(_ appearance: AppearanceSettings) {
        defaults.set(appearance.themePresetID,        forKey: Keys.themePresetID)
        defaults.set(appearance.layoutModeRaw,        forKey: Keys.layoutMode)
        defaults.set(appearance.dashboardStyleRaw,    forKey: Keys.dashboardStyle)
        defaults.set(appearance.sidebarStyleRaw,      forKey: Keys.sidebarStyle)
        defaults.set(appearance.backgroundStyleRaw,   forKey: Keys.backgroundStyle)
        defaults.set(appearance.animationLevelRaw,    forKey: Keys.animationLevel)
        defaults.set(appearance.followsSystemAppearance, forKey: Keys.followsSystem)
        defaults.set(appearance.highContrast,         forKey: Keys.highContrast)
        defaults.set(appearance.kitchenMode,          forKey: Keys.kitchenMode)
        defaults.set(appearance.textSizeModifier,     forKey: Keys.textSizeModifier)
        defaults.set(appearance.animationsEnabled,    forKey: Keys.animationsOn)
        defaults.set(appearance.reduceMotion,         forKey: Keys.reduceMotion)
        defaults.set(appearance.reduceGraphicsEffects, forKey: Keys.reduceGraphics)
    }
}
