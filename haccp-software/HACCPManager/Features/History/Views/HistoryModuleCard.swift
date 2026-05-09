import SwiftUI

struct HistoryModuleCard: View {
    let module: HistoryModule
    let entries: [HistoryEntry]

    private var lastEntry: HistoryEntry? {
        entries.sorted { $0.date > $1.date }.first
    }

    private var criticalCount: Int {
        entries.filter(\.hasCriticality).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: module.icon)
                    .font(.title2)
                    .foregroundColor(.red)
                Spacer()
                if criticalCount > 0 {
                    Text("\(criticalCount)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .cornerRadius(10)
                }
            }

            Text(module.rawValue)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(2)

            Text("\(entries.count) registrazioni")
                .font(.title3.bold())
                .foregroundColor(.white)

            Text(lastEntry.map { "Ultima: \($0.date.formatted(date: .abbreviated, time: .shortened))" } ?? "Nessuna registrazione disponibile")
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .padding(14)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .cornerRadius(16)
    }
}
