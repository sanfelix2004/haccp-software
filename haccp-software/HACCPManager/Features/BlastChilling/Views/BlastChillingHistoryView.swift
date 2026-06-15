import SwiftUI

struct BlastChillingHistoryView: View {
    let records: [BlastChillingRecord]
    var onCreateLabel: ((BlastChillingRecord) -> Void)? = nil

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
                                Text("Data: \(record.startedAt.formatted(date: .abbreviated, time: .shortened))")
                                Text("Inizio: \(record.initialTemperature, specifier: "%.1f") °C")
                                Text("Fine: \(record.finalTemperature.map { String(format: "%.1f °C", $0) } ?? "—")")
                                Text("Fine ora: \(record.endedAt?.formatted(date: .abbreviated, time: .shortened) ?? "—")")
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
                            if record.endedAt != nil, let onCreateLabel {
                                CreateProductionLabelLink {
                                    onCreateLabel(record)
                                }
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
