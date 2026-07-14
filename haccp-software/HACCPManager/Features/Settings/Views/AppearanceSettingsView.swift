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

        VStack(alignment: .leading, spacing: theme.spacing.lg) {
            themeGallery
            SettingsPanelCard(title: "Preferenze") {
                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    Toggle(isOn: Binding(
                        get: { storage.appearance.kitchenMode },
                        set: { theme.setKitchenMode($0) }
                    )) {
                        SettingLabel(
                            title: "Modalità cucina",
                            icon: "fork.knife",
                            description: "Testo grande e touch esteso."
                        )
                    }

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
                        SettingLabel(title: "Segui sistema", icon: "circle.lefthalf.filled")
                    }
                }
            }

            SettingsExpandableCard(title: "Accessibilità", caption: "Testo, contrasto e animazioni") {
                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    if !storage.appearance.kitchenMode {
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
                    }

                    Toggle(isOn: Binding(
                        get: { storage.appearance.highContrast },
                        set: { theme.setHighContrast($0) }
                    )) {
                        SettingLabel(title: "Alto contrasto", icon: "circle.lefthalf.striped.horizontal")
                    }

                    Toggle(isOn: Binding(
                        get: { storage.appearance.reduceMotion },
                        set: { theme.setReduceMotion($0) }
                    )) {
                        SettingLabel(title: "Riduci movimento", icon: "tortoise.fill")
                    }
                }
            }
        }
    }

    private var themeGallery: some View {
        SettingsPanelCard(title: "Tema") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(AppTheme.allPresets, id: \.id) { preset in
                    let selected = storage.appearance.themePresetID == preset.id
                        || AppTheme.preset(forID: storage.appearance.themePresetID).id == preset.id
                    Button {
                        HapticManager.shared.selection()
                        theme.selectPreset(preset)
                    } label: {
                        HStack(spacing: 10) {
                            HStack(spacing: 6) {
                                Circle().fill(preset.primary).frame(width: 12, height: 12)
                                Circle().fill(preset.background).frame(width: 12, height: 12)
                                Circle().fill(preset.surface).frame(width: 12, height: 12)
                            }
                            Text(preset.name)
                                .font(theme.typography.subheadline.weight(.semibold))
                                .foregroundStyle(theme.colorTextPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(theme.colorPrimary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
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
    }
}
