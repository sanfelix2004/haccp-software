import SwiftUI

struct HistoryRecordCard: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.headline)
                        .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                    Text("\(entry.status) · \(entry.operatorName)")
                        .font(.caption)
                        .foregroundStyle(entry.hasCriticality ? ThemeManager.shared.colorWarning : ThemeManager.shared.colorTextSecondary)
                }
                Spacer()
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(entry.details) { detail in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(detail.label)
                            .font(.caption2.bold())
                            .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                        Text(detail.value)
                            .font(.caption)
                            .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(ThemeManager.shared.colorSurfaceElevated)
                    .cornerRadius(8)
                }
            }
        }
        .padding(12)
        .background(entry.hasCriticality ? Color.red.opacity(0.12) : ThemeManager.shared.colorSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(entry.hasCriticality ? Color.red.opacity(0.35) : ThemeManager.shared.colorDivider, lineWidth: 1)
        )
        .cornerRadius(12)
    }
}
