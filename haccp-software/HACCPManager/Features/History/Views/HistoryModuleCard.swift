import SwiftUI

struct HistoryModuleCard: View {
    let module: HistoryModule
    let entries: [HistoryEntry]

    @Environment(\.theme) private var theme

    private var lastEntry: HistoryEntry? {
        entries.max(by: { $0.date < $1.date })
    }

    private var criticalCount: Int {
        entries.filter(\.hasCriticality).count
    }

    private var accent: Color {
        module.accentColor(theme: theme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accent.opacity(0.16))
                        .frame(width: 44, height: 44)
                    Image(systemName: module.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(accent)
                }
                Spacer()
                if criticalCount > 0 {
                    HACCPBadge(title: "\(criticalCount)", style: .nonConforme, showIcon: false)
                } else if entries.isEmpty {
                    HACCPBadge(title: "Vuoto", style: .neutral, showIcon: false)
                }
            }

            Spacer(minLength: 12)

            Text(module.shortTitle)
                .font(theme.typography.headline)
                .foregroundStyle(theme.colorTextPrimary)
                .lineLimit(2)

            Text("\(entries.count)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(entries.isEmpty ? theme.colorTextSecondary : theme.colorTextPrimary)
                .padding(.top, 4)

            Text(entries.count == 1 ? "registrazione" : "registrazioni")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)

            if let last = lastEntry {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(last.date.formatted(date: .abbreviated, time: .shortened))
                        .font(theme.typography.caption2)
                }
                .foregroundStyle(theme.colorTextSecondary)
                .lineLimit(1)
                .padding(.top, 8)
            } else {
                Text("Nessun dato ancora")
                    .font(theme.typography.caption2)
                    .foregroundStyle(theme.colorTextSecondary)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .fill(theme.colorSurfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .strokeBorder(accent.opacity(entries.isEmpty ? 0.15 : 0.35), lineWidth: 1.5)
        )
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .fill(accent.opacity(0.07))
                .frame(height: 56)
                .allowsHitTesting(false)
        }
    }
}
