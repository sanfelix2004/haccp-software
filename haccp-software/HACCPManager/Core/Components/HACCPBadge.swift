//
//  HACCPBadge.swift
//  Badge semantici HACCP premium.
//

import SwiftUI

enum HACCPBadgeStyle {
    case conforme
    case nonConforme
    case warning
    case info
    case neutral

    func colors(theme: ThemeManager) -> (fg: Color, bg: Color) {
        switch self {
        case .conforme:
            return (theme.colorSuccess, theme.colorSuccess.opacity(0.15))
        case .nonConforme:
            return (theme.colorError, theme.colorError.opacity(0.18))
        case .warning:
            return (theme.colorWarning, theme.colorWarning.opacity(0.18))
        case .info:
            return (theme.colorInfo, theme.colorInfo.opacity(0.18))
        case .neutral:
            return (theme.colorTextSecondary, theme.colorSurfaceElevated)
        }
    }

    var icon: String {
        switch self {
        case .conforme: return "checkmark.circle.fill"
        case .nonConforme: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .neutral: return "circle.fill"
        }
    }
}

struct HACCPBadge: View {
    let title: String
    var style: HACCPBadgeStyle = .neutral
    var showIcon: Bool = true

    @Environment(\.theme) private var theme

    var body: some View {
        let palette = style.colors(theme: theme)
        HStack(spacing: 6) {
            if showIcon {
                Image(systemName: style.icon)
                    .font(.caption.weight(.semibold))
            }
            Text(title)
                .font(theme.typography.caption.weight(.semibold))
        }
        .foregroundStyle(palette.fg)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(palette.bg)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(palette.fg.opacity(0.25), lineWidth: 0.5)
        )
    }
}
