//
//  PremiumSidebarView.swift
//  Sidebar floating / blur enterprise.
//

import SwiftUI

struct PremiumSidebarView: View {
    @Binding var selectedItem: SidebarItem?
    let activeRestaurant: Restaurant?
    let restaurantsCount: Int
    let isMaster: Bool
    let onSwitchRestaurant: () -> Void
    let onLogout: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            restaurantCard
                .padding(.horizontal, theme.spacing.lg)
                .padding(.top, theme.spacing.xl)
                .padding(.bottom, theme.spacing.md)

            List(selection: $selectedItem) {
                Section {
                    sidebarRow(.dashboard)
                } header: {
                    sectionHeader("Overview")
                }

                Section {
                    ForEach(SidebarItem.haccpModulesInOrder) { sidebarRow($0) }
                } header: {
                    sectionHeader("Moduli HACCP")
                }

                Section {
                    ForEach(SidebarItem.toolsInOrder) { item in
                        if item == .users {
                            if isMaster { sidebarRow(item) }
                        } else {
                            sidebarRow(item)
                        }
                    }
                } header: {
                    sectionHeader("Sistema")
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            logoutButton
                .padding(theme.spacing.lg)
        }
        .background(sidebarBackground)
        .onChange(of: selectedItem) { _, _ in
            HapticManager.shared.selection()
        }
    }

    @ViewBuilder
    private var sidebarBackground: some View {
        let style = theme.sidebarStyle
        let reduceFx = theme.appearance.reduceGraphicsEffects

        Group {
            if style == .blur && !reduceFx {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .background(theme.colorSurface.opacity(0.65))
            } else {
                theme.colorSurface
            }
        }
    }

    private var restaurantCard: some View {
        Button(action: {
            if restaurantsCount > 1 {
                HapticManager.shared.selection()
                onSwitchRestaurant()
            }
        }) {
            HStack(spacing: theme.spacing.lg) {
                restaurantLogo
                VStack(alignment: .leading, spacing: 4) {
                    Text(activeRestaurant?.name ?? "HACCP Manager")
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colorTextPrimary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(theme.colorSuccess)
                            .frame(width: 8, height: 8)
                        Text(activeRestaurant?.city ?? "Attività")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                            .textCase(.uppercase)
                    }
                }
                Spacer(minLength: 0)
                if restaurantsCount > 1 {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }
            .padding(theme.spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                    .fill(theme.colorSurfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                    .stroke(theme.colorPrimary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var restaurantLogo: some View {
        let size: CGFloat = 56
        if let logoData = activeRestaurant?.logoData, let uiImage = UIImage(data: logoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.colorPrimary.opacity(0.25), theme.colorPrimary.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "fork.knife")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(theme.colorPrimary)
                )
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(theme.typography.caption.weight(.black))
            .foregroundStyle(theme.colorTextSecondary)
            .textCase(.uppercase)
            .tracking(1.2)
    }

    private func sidebarRow(_ item: SidebarItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(selectedItem == item ? theme.colorPrimary : theme.colorTextSecondary)
                .frame(width: 24)
            Text(item.rawValue)
                .font(theme.typography.body)
                .foregroundStyle(selectedItem == item ? theme.colorTextPrimary : theme.colorTextSecondary)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
        .tag(item)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selectedItem == item ? theme.colorPrimary.opacity(0.12) : Color.clear)
        )
    }

    private var logoutButton: some View {
        Button(action: onLogout) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Esci dal sistema")
                    .font(theme.typography.headline)
            }
            .foregroundStyle(theme.colorPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                    .fill(theme.colorPrimary.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                    .stroke(theme.colorPrimary.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(PremiumPressButtonStyle())
    }
}
