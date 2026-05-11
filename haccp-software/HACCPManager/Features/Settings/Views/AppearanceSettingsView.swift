//
//  AppearanceSettingsView.swift
//  HACCP Manager — Settings → Aspetto e layout
//
//  UI di controllo del sistema "Layout & Themes" enterprise.
//  Esplosa in 7 sotto-sezioni con preview live persistente.
//

import SwiftUI

// MARK: - Sub-sections enum

enum AppearancePane: Int, CaseIterable, Identifiable {
    case theme         = 0
    case layout        = 1
    case colors        = 2
    case dashboard     = 3
    case sidebar       = 4
    case animations    = 5
    case accessibility = 6

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .theme:         return "Tema"
        case .layout:        return "Layout"
        case .colors:        return "Colori"
        case .dashboard:     return "Dashboard"
        case .sidebar:       return "Sidebar"
        case .animations:    return "Animazioni"
        case .accessibility: return "Accessibilità"
        }
    }

    var icon: String {
        switch self {
        case .theme:         return "paintpalette.fill"
        case .layout:        return "rectangle.split.3x1"
        case .colors:        return "drop.fill"
        case .dashboard:     return "square.grid.2x2.fill"
        case .sidebar:       return "sidebar.left"
        case .animations:    return "wand.and.stars"
        case .accessibility: return "accessibility.fill"
        }
    }
}

// MARK: - Root view

struct AppearanceSettingsView: View {
    var storage = SettingsStorageService.shared
    private let theme = ThemeManager.shared

    @State private var selectedPane: AppearancePane = .theme

    var body: some View {
        @Bindable var storage = storage

        VStack(alignment: .leading, spacing: 24) {

            header

            paneSelector

            // Contenuto + preview live affiancati su iPad / impilati su iPhone.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) {
                    paneContent
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    LiveThemePreview()
                        .frame(width: 360)
                }

                VStack(alignment: .leading, spacing: 24) {
                    paneContent
                    LiveThemePreview()
                }
            }
        }
        .animation(theme.motion.standard, value: selectedPane)
        .animation(theme.motion.standard, value: storage.appearance.themePresetID)
        .animation(theme.motion.standard, value: storage.appearance.layoutModeRaw)
        .animation(theme.motion.standard, value: storage.appearance.dashboardStyleRaw)
        .animation(theme.motion.standard, value: storage.appearance.sidebarStyleRaw)
        .animation(theme.motion.standard, value: storage.appearance.backgroundStyleRaw)
        .animation(theme.motion.standard, value: storage.appearance.animationLevelRaw)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aspetto e layout")
                .font(.title.weight(.bold))
                .foregroundColor(ThemeManager.shared.colorTextPrimary)
            Text("Personalizza completamente l'aspetto di HACCP Manager. Tutte le modifiche sono applicate in tempo reale.")
                .font(.callout)
                .foregroundColor(ThemeManager.shared.colorTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Pane selector

    private var paneSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(AppearancePane.allCases) { pane in
                    Button {
                        selectedPane = pane
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: pane.icon)
                            Text(pane.title)
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                            .background(
                            Capsule().fill(
                                selectedPane == pane
                                    ? theme.colorPrimary
                                    : theme.colorSurfaceElevated.opacity(0.6)
                            )
                        )
                        .overlay(
                            Capsule().stroke(
                                selectedPane == pane
                                    ? theme.colorPrimary.opacity(0.5)
                                    : theme.colorDivider,
                                lineWidth: 1
                            )
                        )
                        .foregroundColor(selectedPane == pane
                                         ? theme.colorTextOnPrimary
                                         : theme.colorTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: Pane content

    @ViewBuilder
    private var paneContent: some View {
        switch selectedPane {
        case .theme:         AppearanceThemePane()
        case .layout:        AppearanceLayoutPane()
        case .colors:        AppearanceColorsPane()
        case .dashboard:     AppearanceDashboardPane()
        case .sidebar:       AppearanceSidebarPane()
        case .animations:    AppearanceAnimationsPane()
        case .accessibility: AppearanceAccessibilityPane()
        }
    }
}

// MARK: - Pane: Tema

private struct AppearanceThemePane: View {
    var storage = SettingsStorageService.shared
    private let theme = ThemeManager.shared

    var body: some View {
        @Bindable var storage = storage

        VStack(alignment: .leading, spacing: 20) {
            PaneHeader(
                title: "Tema preset",
                subtitle: "Sei combinazioni professionali pronte all'uso. Selezionane una per ridipingere l'intera app."
            )

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 280), spacing: 14)
            ], spacing: 14) {
                ForEach(AppTheme.allPresets) { preset in
                    ThemePresetCard(
                        preset: preset,
                        isSelected: storage.appearance.themePresetID == preset.id
                            && !storage.appearance.followsSystemAppearance
                    ) {
                        theme.selectPreset(preset)
                    }
                }
            }

            Divider().overlay(ThemeManager.shared.colorDivider)

            Toggle(isOn: Binding(
                get: { storage.appearance.followsSystemAppearance },
                set: { theme.setFollowsSystem($0) }
            )) {
                SettingLabel(
                    title: "Segui il sistema",
                    icon: "circle.lefthalf.filled",
                    description: "Quando attivo, ignora il preset e segue Modalità Scura/Chiara del dispositivo."
                )
            }
        }
        .padding(20)
        .background(ThemeManager.shared.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ThemePresetCard: View {
    let preset: AppTheme
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {

                // Color swatches (mini-preview)
                HStack(spacing: 6) {
                    swatch(preset.background)
                    swatch(preset.surface)
                    swatch(preset.primary)
                    swatch(preset.accent)
                    swatch(preset.secondary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                    }
                }

                Text(preset.name)
                    .font(.headline)
                    .foregroundColor(ThemeManager.shared.colorTextPrimary)

                Text(preset.descriptionText)
                    .font(.caption)
                    .foregroundColor(ThemeManager.shared.colorTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Mini-preview "carta"
                HStack(spacing: 8) {
                    miniCard(in: preset)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preset.isLight ? "Light" : "Dark")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(preset.primary.opacity(0.18)))
                            .foregroundColor(preset.primary)
                        Text(preset.defaultDashboardStyle.label)
                            .font(.caption2)
                            .foregroundColor(ThemeManager.shared.colorTextSecondary)
                    }
                    Spacer()
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected
                          ? ThemeManager.shared.colorSurfaceElevated
                          : ThemeManager.shared.colorSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected
                            ? ThemeManager.shared.colorSuccess
                            : ThemeManager.shared.colorDivider,
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func swatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(color)
            .frame(width: 22, height: 22)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(ThemeManager.shared.colorDivider, lineWidth: 0.5)
            )
    }

    private func miniCard(in preset: AppTheme) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(preset.background)
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(preset.primary)
                    .frame(width: 28, height: 4)
                RoundedRectangle(cornerRadius: 3)
                    .fill(preset.textSecondary.opacity(0.5))
                    .frame(width: 44, height: 3)
                RoundedRectangle(cornerRadius: 3)
                    .fill(preset.textSecondary.opacity(0.3))
                    .frame(width: 36, height: 3)
            }
            .padding(8)
        }
        .frame(width: 70, height: 50)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(preset.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Pane: Layout

private struct AppearanceLayoutPane: View {
    var storage = SettingsStorageService.shared
    private let theme = ThemeManager.shared

    var body: some View {
        @Bindable var storage = storage

        VStack(alignment: .leading, spacing: 20) {
            PaneHeader(
                title: "Modalità layout",
                subtitle: "Adatta la densità dell'interfaccia al tuo contesto operativo."
            )

            VStack(spacing: 10) {
                ForEach(LayoutMode.allCases) { mode in
                    OptionRow(
                        title: mode.label,
                        helper: mode.helper,
                        icon: mode.icon,
                        isSelected: storage.appearance.layoutMode == mode
                    ) {
                        theme.setLayoutMode(mode)
                    }
                }
            }

            tipsBox
        }
        .padding(20)
        .background(ThemeManager.shared.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var tipsBox: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(ThemeManager.shared.colorWarning)
            Text("Suggerimento: per uso in cucina con guanti, scegli **Large Touch** insieme alla **Modalità cucina** (Accessibilità).")
                .font(.caption)
                .foregroundColor(ThemeManager.shared.colorTextPrimary)
        }
        .padding(12)
        .background(ThemeManager.shared.colorWarning.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ThemeManager.shared.colorWarning.opacity(0.30), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Pane: Colori (palette read-only del tema corrente)

private struct AppearanceColorsPane: View {
    var storage = SettingsStorageService.shared

    var body: some View {
        @Bindable var storage = storage
        let preset = storage.appearance.resolvedTheme

        VStack(alignment: .leading, spacing: 18) {
            PaneHeader(
                title: "Palette del tema",
                subtitle: "Colori semantici utilizzati dall'app. Cambia preset per modificarli — niente hard-coded."
            )

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150), spacing: 12)
            ], spacing: 12) {
                ColorChip(name: "Background",   color: preset.background,      hex: preset.backgroundHex)
                ColorChip(name: "Surface",      color: preset.surface,         hex: preset.surfaceHex)
                ColorChip(name: "Surface Elev", color: preset.surfaceElevated, hex: preset.surfaceElevatedHex)
                ColorChip(name: "Primary",      color: preset.primary,         hex: preset.primaryHex)
                ColorChip(name: "Accent",       color: preset.accent,          hex: preset.accentHex)
                ColorChip(name: "Secondary",    color: preset.secondary,       hex: preset.secondaryHex)
                ColorChip(name: "Text",         color: preset.textPrimary,     hex: preset.textPrimaryHex)
                ColorChip(name: "Text 2",       color: preset.textSecondary,   hex: preset.textSecondaryHex)
                ColorChip(name: "Success",      color: preset.success,         hex: preset.successHex)
                ColorChip(name: "Warning",      color: preset.warning,         hex: preset.warningHex)
                ColorChip(name: "Error",        color: preset.error,           hex: preset.errorHex)
                ColorChip(name: "Info",         color: preset.info,            hex: preset.infoHex)
            }

            Toggle(isOn: Binding(
                get: { storage.appearance.highContrast },
                set: { ThemeManager.shared.setHighContrast($0) }
            )) {
                SettingLabel(
                    title: "Alto contrasto",
                    icon: "circle.lefthalf.striped.horizontal",
                    description: "Aumenta la separazione testo/sfondo per leggibilità in cucina."
                )
            }
        }
        .padding(20)
        .background(ThemeManager.shared.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ColorChip: View {
    let name: String
    let color: Color
    let hex: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .frame(height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
            Text(name).font(.caption.weight(.semibold)).foregroundColor(ThemeManager.shared.colorTextPrimary)
            Text(hex.uppercased()).font(.caption2.monospaced()).foregroundColor(ThemeManager.shared.colorTextSecondary)
        }
    }
}

// MARK: - Pane: Dashboard

private struct AppearanceDashboardPane: View {
    var storage = SettingsStorageService.shared
    private let theme = ThemeManager.shared

    var body: some View {
        @Bindable var storage = storage

        VStack(alignment: .leading, spacing: 18) {
            PaneHeader(
                title: "Stile dashboard",
                subtitle: "Definisce l'aspetto delle card della home e dei riepiloghi."
            )

            VStack(spacing: 10) {
                ForEach(DashboardStyle.allCases) { style in
                    OptionRow(
                        title: style.label,
                        helper: style.helper,
                        icon: style.icon,
                        isSelected: storage.appearance.resolvedDashboardStyle == style
                            && storage.appearance.dashboardStyleRaw == style.rawValue
                    ) {
                        theme.setDashboardStyle(style)
                    }
                }
            }

            Button {
                theme.setDashboardStyle(nil)
            } label: {
                Label("Ripristina default del preset", systemImage: "arrow.uturn.backward")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(ThemeManager.shared.colorTextSecondary)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Capsule().fill(ThemeManager.shared.colorSurfaceElevated))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(ThemeManager.shared.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Pane: Sidebar

private struct AppearanceSidebarPane: View {
    var storage = SettingsStorageService.shared
    private let theme = ThemeManager.shared

    var body: some View {
        @Bindable var storage = storage

        VStack(alignment: .leading, spacing: 18) {
            PaneHeader(
                title: "Stile sidebar",
                subtitle: "Il menu laterale si adatta al tema. Su iPad la sidebar è sempre visibile."
            )

            VStack(spacing: 10) {
                ForEach(SidebarStyle.allCases) { style in
                    OptionRow(
                        title: style.label,
                        helper: style.helper,
                        icon: style.icon,
                        isSelected: storage.appearance.resolvedSidebarStyle == style
                            && storage.appearance.sidebarStyleRaw == style.rawValue
                    ) {
                        theme.setSidebarStyle(style)
                    }
                }
            }

            Divider().overlay(ThemeManager.shared.colorDivider)

            PaneHeader(
                title: "Background",
                subtitle: "Sfondo dell'app: solido, gradiente, animato leggero..."
            )

            VStack(spacing: 10) {
                ForEach(BackgroundStyle.allCases) { style in
                    OptionRow(
                        title: style.label,
                        helper: style.helper,
                        icon: style.icon,
                        isSelected: storage.appearance.resolvedBackgroundStyle == style
                            && storage.appearance.backgroundStyleRaw == style.rawValue
                    ) {
                        theme.setBackgroundStyle(style)
                    }
                }
            }
        }
        .padding(20)
        .background(ThemeManager.shared.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Pane: Animazioni

private struct AppearanceAnimationsPane: View {
    var storage = SettingsStorageService.shared
    private let theme = ThemeManager.shared

    var body: some View {
        @Bindable var storage = storage

        VStack(alignment: .leading, spacing: 18) {
            PaneHeader(
                title: "Animazioni",
                subtitle: "Gestisci transizioni, hover e comparsa modali. Sui dispositivi datati seleziona Ridotte o Nessuna."
            )

            VStack(spacing: 10) {
                ForEach(AnimationLevel.allCases.reversed()) { level in
                    OptionRow(
                        title: level.label,
                        helper: level.helper,
                        icon: level.icon,
                        isSelected: storage.appearance.animationLevel == level
                    ) {
                        theme.setAnimationLevel(level)
                    }
                }
            }

            Divider().overlay(ThemeManager.shared.colorDivider)

            Toggle(isOn: Binding(
                get: { storage.appearance.reduceMotion },
                set: { theme.setReduceMotion($0) }
            )) {
                SettingLabel(
                    title: "Riduci movimento",
                    icon: "tortoise.fill",
                    description: "Ignora gli effetti di motion per accessibilità (es. parallax, spring)."
                )
            }

            Toggle(isOn: Binding(
                get: { storage.appearance.reduceGraphicsEffects },
                set: { theme.setReduceGraphics($0) }
            )) {
                SettingLabel(
                    title: "Riduci effetti grafici",
                    icon: "sparkles.slash",
                    description: "Disattiva blur, glow e ombre. Massima fluidità su iPad più vecchi."
                )
            }
        }
        .padding(20)
        .background(ThemeManager.shared.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Pane: Accessibilità

private struct AppearanceAccessibilityPane: View {
    var storage = SettingsStorageService.shared
    private let theme = ThemeManager.shared

    var body: some View {
        @Bindable var storage = storage

        VStack(alignment: .leading, spacing: 18) {
            PaneHeader(
                title: "Accessibilità",
                subtitle: "Adatta l'app a chi opera in cucina o a chi ha esigenze specifiche."
            )

            // Slider per text size
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "textformat.size")
                        .foregroundColor(ThemeManager.shared.colorPrimary)
                    Text("Dimensione testo")
                        .font(.headline)
                        .foregroundColor(ThemeManager.shared.colorTextPrimary)
                    Spacer()
                    Text(String(format: "×%.2f", storage.appearance.textSizeModifier))
                        .font(.subheadline.monospaced())
                        .foregroundColor(ThemeManager.shared.colorTextSecondary)
                }
                Slider(
                    value: Binding(
                        get: { storage.appearance.textSizeModifier },
                        set: { theme.setTextSize($0) }
                    ),
                    in: 0.85...1.4,
                    step: 0.05
                )
                .tint(ThemeManager.shared.colorPrimary)
                Text("Da 85% a 140%. Si applica all'intera app.")
                    .font(.caption)
                    .foregroundColor(ThemeManager.shared.colorTextSecondary)
            }
            .padding(12)
            .background(ThemeManager.shared.colorSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Toggle(isOn: Binding(
                get: { storage.appearance.highContrast },
                set: { theme.setHighContrast($0) }
            )) {
                SettingLabel(
                    title: "Alto contrasto",
                    icon: "circle.lefthalf.striped.horizontal",
                    description: "Aumenta la leggibilità in cucine illuminate intensamente."
                )
            }

            Toggle(isOn: Binding(
                get: { storage.appearance.reduceMotion },
                set: { theme.setReduceMotion($0) }
            )) {
                SettingLabel(
                    title: "Riduci movimento",
                    icon: "tortoise.fill",
                    description: "Per chi è sensibile al motion. Riduce transizioni a fade essenziali."
                )
            }

            // Kitchen Mode preset
            Toggle(isOn: Binding(
                get: { storage.appearance.kitchenMode },
                set: { theme.setKitchenMode($0) }
            )) {
                SettingLabel(
                    title: "Modalità cucina",
                    icon: "fork.knife",
                    description: "Preset speciale: alto contrasto, Large Touch, bottoni enormi, animazioni ridotte. Perfetto per uso operativo."
                )
            }
        }
        .padding(20)
        .background(ThemeManager.shared.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Live preview (always visible)

private struct LiveThemePreview: View {
    var storage = SettingsStorageService.shared

    var body: some View {
        @Bindable var storage = storage
        let preset = storage.appearance.resolvedTheme
        let dashStyle = storage.appearance.resolvedDashboardStyle
        let bgStyle = storage.appearance.resolvedBackgroundStyle
        let sideStyle = storage.appearance.resolvedSidebarStyle
        let layout = storage.appearance.layoutMode

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye.fill")
                    .foregroundColor(ThemeManager.shared.colorTextSecondary)
                Text("Anteprima live")
                    .font(.headline)
                    .foregroundColor(ThemeManager.shared.colorTextPrimary)
                Spacer()
                Text(preset.name)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(ThemeManager.shared.colorSurfaceElevated))
                    .foregroundColor(ThemeManager.shared.colorTextSecondary)
            }

            previewWindow(preset: preset,
                          dashboard: dashStyle,
                          background: bgStyle,
                          sidebar: sideStyle,
                          layout: layout)

            // Spec strip
            VStack(alignment: .leading, spacing: 6) {
                specRow("Dashboard", dashStyle.label)
                specRow("Sidebar",   sideStyle.label)
                specRow("Sfondo",    bgStyle.label)
                specRow("Layout",    layout.label)
                specRow("Animazioni",
                        storage.appearance.animationLevel.label
                            + (storage.appearance.reduceMotion ? " (motion ridotto)" : ""))
            }
            .padding(12)
            .background(ThemeManager.shared.colorSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(ThemeManager.shared.colorSurfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ThemeManager.shared.colorDivider, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func specRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.caption2).foregroundColor(ThemeManager.shared.colorTextSecondary)
            Spacer()
            Text(v).font(.caption2.weight(.semibold)).foregroundColor(ThemeManager.shared.colorTextPrimary)
        }
    }

    @ViewBuilder
    private func previewWindow(preset: AppTheme,
                               dashboard: DashboardStyle,
                               background: BackgroundStyle,
                               sidebar: SidebarStyle,
                               layout: LayoutMode) -> some View {
        let corner: CGFloat = 14
        let h: CGFloat = 220

        ZStack {
            // Background
            previewBackground(preset: preset, style: background)

            HStack(spacing: 0) {
                // Sidebar
                previewSidebar(preset: preset, style: sidebar)
                    .frame(width: sidebar == .compact ? 36 : 72)

                // Contenuto
                VStack(alignment: .leading, spacing: 8) {

                    HStack {
                        Circle()
                            .fill(preset.primary)
                            .frame(width: 8, height: 8)
                        Text("HACCP Manager")
                            .font(.caption.weight(.bold))
                            .foregroundColor(preset.textPrimary)
                        Spacer()
                        Text("OK")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(preset.success.opacity(0.2)))
                            .foregroundColor(preset.success)
                    }

                    LazyVGrid(columns: [
                        GridItem(.flexible()), GridItem(.flexible())
                    ], spacing: 6) {
                        previewCard(preset: preset, style: dashboard, title: "Ricezione", value: "12")
                        previewCard(preset: preset, style: dashboard, title: "Temperat.", value: "4°C")
                        previewCard(preset: preset, style: dashboard, title: "Lotti",    value: "38")
                        previewCard(preset: preset, style: dashboard, title: "Alerts",   value: "0")
                    }
                }
                .padding(10)
            }
        }
        .frame(height: h)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(preset.border, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func previewBackground(preset: AppTheme, style: BackgroundStyle) -> some View {
        switch style {
        case .solid:
            preset.background
        case .gradient:
            LinearGradient(
                colors: [preset.background, preset.backgroundEnd ?? preset.background],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .minimal:
            preset.background
        case .texture:
            ZStack {
                preset.background
                Color.white.opacity(preset.isLight ? 0.03 : 0.02)
            }
        case .animated:
            ZStack {
                preset.background
                Circle()
                    .fill(preset.primary.opacity(0.25))
                    .blur(radius: 60)
                    .offset(x: -50, y: -30)
                Circle()
                    .fill((preset.glow ?? preset.accent).opacity(0.18))
                    .blur(radius: 80)
                    .offset(x: 80, y: 50)
            }
        }
    }

    @ViewBuilder
    private func previewSidebar(preset: AppTheme, style: SidebarStyle) -> some View {
        ZStack {
            switch style {
            case .full, .compact, .solid:
                preset.surface
            case .floating:
                preset.surfaceElevated.opacity(0.9)
            case .blur:
                preset.surface.opacity(0.5)
                Rectangle().fill(.ultraThinMaterial)
            }

            VStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(i == 0 ? preset.primary : preset.textSecondary.opacity(0.35))
                        .frame(width: style == .compact ? 14 : 30, height: 6)
                }
                Spacer()
            }
            .padding(.top, 10)
        }
        .padding(style == .floating ? 6 : 0)
    }

    @ViewBuilder
    private func previewCard(preset: AppTheme, style: DashboardStyle, title: String, value: String) -> some View {
        let corner = style.cardCornerRadiusBase * 0.6
        ZStack {
            if style == .glassmorphism {
                RoundedRectangle(cornerRadius: corner)
                    .fill(preset.surface.opacity(0.4))
                RoundedRectangle(cornerRadius: corner)
                    .fill(.ultraThinMaterial)
            } else {
                RoundedRectangle(cornerRadius: corner)
                    .fill(preset.surface)
            }

            if style.usesAccentGlow {
                RoundedRectangle(cornerRadius: corner)
                    .stroke(preset.primary.opacity(0.55), lineWidth: 1)
                    .shadow(color: (preset.glow ?? preset.primary).opacity(0.6), radius: 6)
            } else {
                RoundedRectangle(cornerRadius: corner)
                    .stroke(preset.border.opacity(0.5), lineWidth: 0.5)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(preset.textSecondary)
                Text(value)
                    .font(.headline.weight(.bold))
                    .foregroundColor(preset.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        }
    }
}

// MARK: - Generic helpers

private struct PaneHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundColor(ThemeManager.shared.colorTextPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(ThemeManager.shared.colorTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct OptionRow: View {
    let title: String
    let helper: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected
                              ? ThemeManager.shared.colorPrimary.opacity(0.22)
                              : ThemeManager.shared.colorSurfaceElevated)
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .foregroundColor(isSelected
                                         ? ThemeManager.shared.colorPrimary
                                         : ThemeManager.shared.colorTextSecondary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(ThemeManager.shared.colorTextPrimary)
                    Text(helper)
                        .font(.caption2)
                        .foregroundColor(ThemeManager.shared.colorTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected
                                     ? ThemeManager.shared.colorSuccess
                                     : ThemeManager.shared.colorTextSecondary.opacity(0.4))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected
                          ? ThemeManager.shared.colorSurfaceElevated
                          : ThemeManager.shared.colorSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected
                            ? ThemeManager.shared.colorSuccess.opacity(0.4)
                            : ThemeManager.shared.colorDivider,
                            lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
