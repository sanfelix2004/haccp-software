import Foundation

public struct AppearanceSettings: Codable {

    var theme: Int = 0

    var highContrast: Bool = false
    var textSizeModifier: Double = 1.0
    var animationsEnabled: Bool = true
    var kitchenMode: Bool = false
    var reduceMotion: Bool = false
    var reduceGraphicsEffects: Bool = false

    var themePresetID: String = AppTheme.PresetID.darkPremium
    var layoutModeRaw: Int = LayoutMode.comfortable.rawValue
    var dashboardStyleRaw: Int = -1
    var sidebarStyleRaw: Int = -1
    var backgroundStyleRaw: Int = -1
    var animationLevelRaw: Int = AnimationLevel.full.rawValue
    var followsSystemAppearance: Bool = false
}

public enum AppThemeOption: Int, CaseIterable, Identifiable, Codable {
    case dark = 0
    case light = 1
    case system = 2

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .dark: return "Scuro"
        case .light: return "Chiaro"
        case .system: return "Sistema"
        }
    }

    public var icon: String {
        switch self {
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
}

extension AppearanceSettings {

    var themeOption: AppThemeOption {
        get { AppThemeOption(rawValue: theme) ?? .dark }
        set { theme = newValue.rawValue }
    }

    var layoutMode: LayoutMode {
        get { LayoutMode(rawValue: layoutModeRaw) ?? .comfortable }
        set { layoutModeRaw = newValue.rawValue }
    }

    var animationLevel: AnimationLevel {
        get { AnimationLevel(rawValue: animationLevelRaw) ?? .full }
        set { animationLevelRaw = newValue.rawValue }
    }

    var resolvedTheme: AppTheme {
        AppTheme.preset(forID: themePresetID)
    }

    var resolvedDashboardStyle: DashboardStyle {
        if dashboardStyleRaw >= 0, let s = DashboardStyle(rawValue: dashboardStyleRaw) {
            return s
        }
        return resolvedTheme.defaultDashboardStyle
    }

    var resolvedSidebarStyle: SidebarStyle {
        if sidebarStyleRaw >= 0, let s = SidebarStyle(rawValue: sidebarStyleRaw) {
            return s
        }
        return resolvedTheme.defaultSidebarStyle
    }

    var resolvedBackgroundStyle: BackgroundStyle {
        if backgroundStyleRaw >= 0, let s = BackgroundStyle(rawValue: backgroundStyleRaw) {
            return s
        }
        return resolvedTheme.defaultBackgroundStyle
    }

    var resolvedLayoutMode: LayoutMode {
        kitchenMode ? .largeTouch : layoutMode
    }

    mutating func normalizeStoredPreferences() {
        _ = AppTheme.preset(forID: themePresetID)
        if dashboardStyleRaw >= 0, DashboardStyle(rawValue: dashboardStyleRaw) == nil {
            dashboardStyleRaw = -1
        }
        if sidebarStyleRaw >= 0, SidebarStyle(rawValue: sidebarStyleRaw) == nil {
            sidebarStyleRaw = -1
        }
        if backgroundStyleRaw >= 0, BackgroundStyle(rawValue: backgroundStyleRaw) == nil {
            backgroundStyleRaw = -1
        }
    }

    /// Compat: vecchie chiamate che forzavano il tema chiaro.
    mutating func enforceBrandAppearance() {
        normalizeStoredPreferences()
    }
}
