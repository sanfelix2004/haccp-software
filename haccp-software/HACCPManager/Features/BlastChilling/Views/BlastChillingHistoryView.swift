import SwiftUI

struct BlastChillingHistoryView: View {
    let records: [BlastChillingRecord]

    var body: some View {
        DashboardCardView(title: "Storico abbattimenti") {
            if records.isEmpty {
                DashboardEmptyStateView(state: .init(
                    title: "Nessun abbattimento registrato",
                    message: "Le registrazioni reali appariranno qui dopo il salvataggio.",
                    actionTitle: nil
                ))
            } else {
                VStack(spacing: 10) {
                    ForEach(records) { record in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(record.productionNameSnapshot)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(record.productionCategorySnapshot)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Text(record.status.label)
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(record.status == .conforme ? Color.green.opacity(0.75) : Color.orange.opacity(0.85))
                                    .cornerRadius(8)
                            }
                            HStack(spacing: 10) {
                                Text("Data: \(record.startedAt.formatted(date: .abbreviated, time: .shortened))")
                                Text("Inizio: \(record.initialTemperature, specifier: "%.1f") °C")
                                Text("Fine: \(record.finalTemperature.map { String(format: "%.1f °C", $0) } ?? "—")")
                                Text("Fine ora: \(record.endedAt?.formatted(date: .abbreviated, time: .shortened) ?? "—")")
                                Text("Operatore: \(record.createdByNameSnapshot)")
                            }
                            .font(.caption2)
                            .foregroundColor(.gray)
                            if let notes = record.notes, !notes.isEmpty {
                                Text("Note: \(notes)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            if let action = record.correctiveAction, !action.isEmpty {
                                Text("Azione correttiva: \(action)")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                    }
                }
            }
        }
    }
}
