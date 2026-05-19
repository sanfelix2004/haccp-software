//
//  StatCard.swift
//  Statistiche dashboard premium.
//

import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var icon: String
    var accent: Color? = nil
    var trend: String? = nil

    @Environment(\.theme) private var theme
    @State private var pressed = false

    var body: some View {
        GlassCard(elevated: true) {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill((accent ?? theme.colorPrimary).opacity(0.14))
                            .frame(width: 44, height: 44)
                        Image(systemName: icon)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(accent ?? theme.colorPrimary)
                    }
                    Spacer()
                    if let trend {
                        Text(trend)
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorSuccess)
                    }
                }

                Text(value)
                    .font(theme.typography.statValue)
                    .foregroundStyle(theme.colorTextPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(title)
                    .font(theme.typography.subheadline)
                    .foregroundStyle(theme.colorTextSecondary)

                if let subtitle {
                    Text(subtitle)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary.opacity(0.85))
                }
            }
        }
        .scaleEffect(pressed ? 0.98 : 1)
        .animation(theme.spring, value: pressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            pressed = pressing
        }, perform: {})
    }
}
