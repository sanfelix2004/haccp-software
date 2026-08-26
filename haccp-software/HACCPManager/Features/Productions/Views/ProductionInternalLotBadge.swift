import SwiftUI

/// Badge lotto interno produzione: sempre leggibile (formato YYYYMMDD-XX).
struct ProductionInternalLotBadge: View {
    let batchCode: String
    var compact: Bool = false

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 6) {
            Text("LOTTO")
                .font(theme.typography.caption2.weight(.bold))
                .foregroundStyle(theme.colorTextSecondary)
                .tracking(0.6)
            Text(displayCode)
                .font(compact
                      ? theme.typography.title3.weight(.bold).monospaced()
                      : theme.typography.title2.weight(.bold).monospaced())
                .foregroundStyle(theme.colorTextPrimary)
                .accessibilityLabel("Lotto \(displayCode)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 10 : 14)
        .background(theme.colorPrimary.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous)
                .strokeBorder(theme.colorPrimary.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous))
    }

    private var displayCode: String {
        let trimmed = batchCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
}
