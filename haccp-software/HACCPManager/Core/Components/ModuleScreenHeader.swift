//
//  ModuleScreenHeader.swift
//  Intestazione moduli HACCP — gerarchia tipografica e accessibilità.
//

import SwiftUI

/// Header premium riutilizzabile per schermate modulo (titolo, sottotitolo, accento opzionale).
struct ModuleScreenHeader: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var help: ModuleHelp? = nil

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            if let systemImage {
                ZStack {
                    RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.colorPrimary.opacity(0.22),
                                    theme.colorPrimary.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.colorPrimary)
                        .accessibilityHidden(true)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(theme.typography.largeTitle)
                    .foregroundStyle(theme.colorTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(theme.typography.subheadline)
                        .foregroundStyle(theme.colorTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            if let help {
                ModuleHelpButton(help: help, size: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Contenitore modulo con padding, sfondo e transizione tab coerenti.
struct ModuleScreenContainer<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.theme) private var theme

    var body: some View {
        content
            .padding(theme.spacing.screenPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(theme.colorBackground.ignoresSafeArea())
    }
}
