import SwiftUI

struct HistoryDateSection: View {
    let date: Date
    let entries: [HistoryEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title(for: date))
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top, 8)

            ForEach(entries) { entry in
                HistoryRecordCard(entry: entry)
            }
        }
    }

    private func title(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Oggi" }
        if calendar.isDateInYesterday(date) { return "Ieri" }
        return date.formatted(date: .complete, time: .omitted)
    }
}
