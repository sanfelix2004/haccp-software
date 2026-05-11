import Foundation

/// Preferenze grafiche persistenti. Backward-compatible: i nuovi campi
/// hanno default sensati, quindi vecchi `AppDataStore` continuano a decodificare.
///
/// `theme` (legacy):
/// - 0 = Scuro (default storico)
/// - 1 = Chiaro
/// - 2 = Sistema
///
/// Il nuovo sistema "Layout & Themes" introduce campi più ricchi
/// (preset, layout, dashboard, sidebar, background, animation) che
/// **prevalgono** sul vecchio `theme` quando `themePresetID` è settato.
public struct AppearanceSettings: Codable {

    // MARK: Legacy (mantenuto per migrazione + Picker classico)
    var theme: Int = 0

    // MARK: Accessibilità
    var highContrast: Bool = false
    var textSizeModifier: Double = 1.0
    var animationsEnabled: Bool = true
    var kitchenMode: Bool = false
    var reduceMotion: Bool = false
    var reduceGraphicsEffects: Bool = false

    // MARK: Nuovo sistema Layout & Themes
    /// ID del preset selezionato (vedi `AppTheme.PresetID`).
    /// Se vuoto/nil ⇒ derivazione dal campo `theme` legacy.
    var themePresetID: String = ""

    /// 0=Compact, 1=Comfortable, 2=LargeTouch (vedi `LayoutMode`).
    var layoutModeRaw: Int = LayoutMode.comfortable.rawValue

    /// Vedi `DashboardStyle`. -1 = "usa default del preset".
    var dashboardStyleRaw: Int = -1

    /// Vedi `SidebarStyle`. -1 = "usa default del preset".
    var sidebarStyleRaw: Int = -1

    /// Vedi `BackgroundStyle`. -1 = "usa default del preset".
    var backgroundStyleRaw: Int = -1

    /// 0=None, 1=Reduced, 2=Full (vedi `AnimationLevel`). Default Full.
    var animationLevelRaw: Int = AnimationLevel.full.rawValue

    /// Override segue-sistema: quando true, ignora il preset e segue lo schema OS.
    var followsSystemAppearance: Bool = false
}

/// Astrazione esplicita del tema selezionato dall'utente (LEGACY).
/// Stabile per binding SwiftUI / Picker.
public enum AppThemeOption: Int, CaseIterable, Identifiable, Codable {
    case dark   = 0
    case light  = 1
    case system = 2

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .dark:   return "Scuro"
        case .light:  return "Chiaro"
        case .system: return "Sistema"
        }
    }

    public var icon: String {
        switch self {
        case .dark:   return "moon.fill"
        case .light:  return "sun.max.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }

    public var helper: String {
        switch self {
        case .dark:   return "Layout scuro premium, ottimizzato per ambienti professionali e bassa luminosità."
        case .light:  return "Layout chiaro ad alto contrasto, ideale in cucina con illuminazione intensa."
        case .system: return "Segue automaticamente le impostazioni del dispositivo (giorno/notte)."
        }
    }
}

extension AppearanceSettings {

    // Legacy alias
    var themeOption: AppThemeOption {
        get { AppThemeOption(rawValue: theme) ?? .dark }
        set { theme = newValue.rawValue }
    }

    // MARK: New typed accessors

    /// Layout density mode (compact/comfortable/largeTouch).
    var layoutMode: LayoutMode {
        get { LayoutMode(rawValue: layoutModeRaw) ?? .comfortable }
        set { layoutModeRaw = newValue.rawValue }
    }

    /// Animation level (none/reduced/full).
    var animationLevel: AnimationLevel {
        get { AnimationLevel(rawValue: animationLevelRaw) ?? .full }
        set { animationLevelRaw = newValue.rawValue }
    }

    /// Preset selezionato. Se nessun preset ID è settato, deriva dal vecchio `theme`.
    var resolvedTheme: AppTheme {
        if !themePresetID.isEmpty {
            return AppTheme.preset(forID: themePresetID)
        }
        switch themeOption {
        case .dark:   return .haccpDarkPro
        case .light:  return .haccpLightPro
        case .system: return .haccpDarkPro
        }
    }

    /// Dashboard style risolto: override utente ⇒ default del preset.
    var resolvedDashboardStyle: DashboardStyle {
        if dashboardStyleRaw >= 0,
           let style = DashboardStyle(rawValue: dashboardStyleRaw) {
            return style
        }
        return resolvedTheme.defaultDashboardStyle
    }

    var resolvedSidebarStyle: SidebarStyle {
        if sidebarStyleRaw >= 0,
           let style = SidebarStyle(rawValue: sidebarStyleRaw) {
            return style
        }
        return resolvedTheme.defaultSidebarStyle
    }

    var resolvedBackgroundStyle: BackgroundStyle {
        if backgroundStyleRaw >= 0,
           let style = BackgroundStyle(rawValue: backgroundStyleRaw) {
            return style
        }
        return resolvedTheme.defaultBackgroundStyle
    }
}
