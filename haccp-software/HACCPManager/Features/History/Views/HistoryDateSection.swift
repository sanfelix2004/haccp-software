import SwiftUI

struct HistoryDateSection: View {
    let date: Date
    let entries: [HistoryEntry]
    var onPendingClosure: ((UUID) -> Void)? = nil
    var canDeleteProduction: Bool = false
    var onDeleteProduction: ((HistoryEntry) -> Void)? = nil

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text(title(for: date))
                    .font(theme.typography.title3.weight(.bold))
                    .foregroundStyle(theme.colorTextPrimary)
                Text(relativeHint(for: date))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                Spacer()
                Text("\(entries.count)")
                    .font(theme.typography.caption.weight(.bold))
                    .foregroundStyle(theme.colorTextSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.colorSurface)
                    .clipShape(Capsule())
            }
            .padding(.bottom, 8)

            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                HistoryRecordCard(
                    entry: entry,
                    isLastInSection: index == entries.count - 1,
                    onPendingClosure: onPendingClosure,
                    canDeleteProduction: canDeleteProduction && entry.allowsHistoryRemoval && entry.produzioneBatchId != nil,
                    onDeleteProduction: { onDeleteProduction?(entry) }
                )
                .equatable()
            }
        }
    }

    private func title(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Oggi" }
        if calendar.isDateInYesterday(date) { return "Ieri" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private func relativeHint(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) || calendar.isDateInYesterday(date) {
            return date.formatted(date: .complete, time: .omitted)
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
