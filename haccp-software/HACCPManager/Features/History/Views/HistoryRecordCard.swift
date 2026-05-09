import SwiftUI

struct HistoryRecordCard: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("\(entry.status) · \(entry.operatorName)")
                        .font(.caption)
                        .foregroundColor(entry.hasCriticality ? .orange : .gray)
                }
                Spacer()
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(entry.details) { detail in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(detail.label)
                            .font(.caption2.bold())
                            .foregroundColor(.gray)
                        Text(detail.value)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                }
            }
        }
        .padding(12)
        .background(entry.hasCriticality ? Color.red.opacity(0.12) : Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(entry.hasCriticality ? Color.red.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}
