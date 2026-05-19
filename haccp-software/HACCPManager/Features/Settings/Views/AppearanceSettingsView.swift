//
//  AppearanceSettingsView.swift
//  Aspetto — temi live, layout e accessibilità cucina.
//

import SwiftUI

struct AppearanceSettingsView: View {
    var storage = SettingsStorageService.shared
    @Environment(\.theme) private var theme

    var body: some View {
        @Bindable var storage = storage

        VStack(alignment: .leading, spacing: theme.spacing.sectionSpacing) {
            themeGallery
            layoutSection(storage: storage)
            accessibilitySection(storage: storage)
        }
    }

    private var themeGallery: some View {
        VStack(alignment: .leading, spacing: theme.spacing.lg) {
            Text("Tema")
                .font(theme.typography.title3)
                .foregroundStyle(theme.colorTextPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(AppTheme.allPresets, id: \.id) { preset in
                    let selected = storage.appearance.themePresetID == preset.id
                        || AppTheme.preset(forID: storage.appearance.themePresetID).id == preset.id
                    Button {
                        HapticManager.shared.selection()
                        theme.selectPreset(preset)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Circle().fill(preset.primary).frame(width: 14, height: 14)
                                Circle().fill(preset.background).frame(width: 14, height: 14)
                                Circle().fill(preset.surface).frame(width: 14, height: 14)
                                Spacer()
                                if selected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(theme.colorPrimary)
                                }
                            }
                            Text(preset.name)
                                .font(theme.typography.headline)
                                .foregroundStyle(theme.colorTextPrimary)
                            Text(preset.descriptionText)
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary)
                                .lineLimit(2)
                        }
                        .padding(theme.spacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                                .fill(selected ? theme.colorPrimary.opacity(0.1) : theme.colorSurfaceElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                                .stroke(selected ? theme.colorPrimary : theme.colorDivider, lineWidth: selected ? 2 : 1)
                        )
                    }
                    .buttonStyle(PremiumPressButtonStyle())
                }
            }
        }
        .padding(theme.spacing.lg)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous))
    }

    private func layoutSection(storage: SettingsStorageService) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.lg) {
            Text("Layout")
                .font(theme.typography.title3)
                .foregroundStyle(theme.colorTextPrimary)

            Picker("Densità", selection: Binding(
                get: { storage.appearance.layoutMode },
                set: { theme.setLayoutMode($0) }
            )) {
                ForEach(LayoutMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(storage.appearance.kitchenMode)

            Toggle(isOn: Binding(
                get: { storage.appearance.followsSystemAppearance },
                set: { theme.setFollowsSystem($0) }
            )) {
                SettingLabel(
                    title: "Segui sistema",
                    icon: "circle.lefthalf.filled",
                    description: "Adatta chiaro/scuro alle impostazioni iPad."
                )
            }
        }
        .padding(theme.spacing.lg)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous))
    }

    private func accessibilitySection(storage: SettingsStorageService) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.lg) {
            Text("Cucina e leggibilità")
                .font(theme.typography.title3)
                .foregroundStyle(theme.colorTextPrimary)

            Toggle(isOn: Binding(
                get: { storage.appearance.kitchenMode },
                set: { theme.setKitchenMode($0) }
            )) {
                SettingLabel(
                    title: "Modalità cucina",
                    icon: "fork.knife",
                    description: "Testo più grande, contrasto alto, touch esteso."
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Dimensione testo")
                        .font(theme.typography.subheadline)
                    Spacer()
                    Text(String(format: "×%.0f%%", storage.appearance.textSizeModifier * 100))
                        .font(theme.typography.caption.monospaced())
                        .foregroundStyle(theme.colorTextSecondary)
                }
                Slider(
                    value: Binding(
                        get: { storage.appearance.textSizeModifier },
                        set: { theme.setTextSize($0) }
                    ),
                    in: 0.85...1.4,
                    step: 0.05
                )
                .tint(theme.colorPrimary)
            }

            Toggle(isOn: Binding(
                get: { storage.appearance.highContrast },
                set: { theme.setHighContrast($0) }
            )) {
                SettingLabel(title: "Alto contrasto", icon: "circle.lefthalf.striped.horizontal", description: nil)
            }

            Toggle(isOn: Binding(
                get: { storage.appearance.reduceMotion },
                set: { theme.setReduceMotion($0) }
            )) {
                SettingLabel(title: "Riduci movimento", icon: "tortoise.fill", description: nil)
            }
        }
        .padding(theme.spacing.lg)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous))
    }
}
