import SwiftUI

enum HistoryPeriodPreset: String, CaseIterable, Identifiable {
    case today = "Oggi"
    case week = "7 giorni"
    case month = "30 giorni"
    case quarter = "3 mesi"

    var id: String { rawValue }

    func apply(to filter: inout HistoryFilter) {
        let calendar = Calendar.current
        let end = Date()
        let start: Date
        switch self {
        case .today:
            start = calendar.startOfDay(for: end)
        case .week:
            start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
        case .month:
            start = calendar.date(byAdding: .day, value: -30, to: end) ?? end
        case .quarter:
            start = calendar.date(byAdding: .month, value: -3, to: end) ?? end
        }
        filter.startDate = start
        filter.endDate = end
    }

    func contains(filter: HistoryFilter) -> Bool {
        var copy = HistoryFilter()
        apply(to: &copy)
        let calendar = Calendar.current
        return calendar.isDate(filter.startDate, inSameDayAs: copy.startDate)
            && calendar.isDate(filter.endDate, inSameDayAs: copy.endDate)
    }
}

extension HistoryModule {
    func accentColor(theme: ThemeManager) -> Color {
        switch self {
        case .goodsReceiving: return theme.colorInfo
        case .traceability: return theme.colorPrimary
        case .fridges: return Color.cyan
        case .cleaningControl: return theme.colorSuccess
        case .blastChilling: return Color.blue
        case .scheduling: return Color.indigo
        case .expiryControl: return theme.colorWarning
        case .defrost: return Color.teal
        case .oilControl: return Color.orange
        case .productionLabels: return Color.purple
        case .moduleTimer: return Color.mint
        case .checklist: return theme.colorPrimary
        }
    }
}

extension HistoryEntry {
    var statusBadgeStyle: HACCPBadgeStyle {
        let normalized = status.lowercased()
        if pendingTraceabilityRecordId != nil || normalized.contains("da chiud") {
            return .warning
        }
        if hasCriticality { return .nonConforme }
        if normalized == "usato" { return .conforme }
        if normalized.contains("scartat") { return .nonConforme }
        if normalized.contains("crit") || normalized.contains("non") {
            return .warning
        }
        if normalized.contains("ok") || normalized.contains("compl") || normalized.contains("conform") {
            return .conforme
        }
        return .info
    }

    var requiresClosureAction: Bool {
        pendingTraceabilityRecordId != nil
    }
}

struct HistoryStatPill: View {
    let title: String
    let value: String
    let icon: String
    var tint: Color?

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint ?? theme.colorPrimary)
                .frame(width: 28, height: 28)
                .background((tint ?? theme.colorPrimary).opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(theme.typography.title3.weight(.bold))
                    .foregroundStyle(theme.colorTextPrimary)
                Text(title)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(theme.colorSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous))
    }
}
