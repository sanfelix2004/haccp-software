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
                                        .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                                    Text(record.productionCategorySnapshot)
                                        .font(.caption)
                                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                }
                                Spacer()
                                HACCPBadge(
                                    title: record.status.label,
                                    style: record.status == .conforme ? .conforme : .warning,
                                    showIcon: false
                                )
                            }
                            HStack(spacing: 10) {
                                Text("Inizio: \(record.startedAt.formatted(date: .abbreviated, time: .shortened))")
                                Text("Durata: \(record.durationText)")
                                Text("Inizio temp: \(record.initialTemperature, specifier: "%.1f") °C")
                                Text("Fine temp: \(record.finalTemperature.map { String(format: "%.1f °C", $0) } ?? "—")")
                                Text("Fine: \(record.endedAt?.formatted(date: .abbreviated, time: .shortened) ?? "—")")
                                Text("Operatore: \(record.createdByNameSnapshot)")
                            }
                            .font(.caption2)
                            .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                            if let notes = record.notes, !notes.isEmpty {
                                Text("Note: \(notes)")
                                    .font(.caption2)
                                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                            }
                            if let action = record.correctiveAction, !action.isEmpty {
                                Text("Azione correttiva: \(action)")
                                    .font(.caption2)
                                    .foregroundStyle(ThemeManager.shared.colorWarning)
                            }
                        }
                        .padding(10)
                        .background(ThemeManager.shared.colorSurface)
                        .cornerRadius(10)
                    }
                }
            }
        }
    }
}
