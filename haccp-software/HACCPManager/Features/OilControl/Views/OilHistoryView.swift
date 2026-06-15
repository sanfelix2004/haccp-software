import SwiftUI

struct OilHistoryView: View {
    let records: [OilControlRecord]
    let canDelete: Bool
    let onDelete: (OilControlRecord) -> Void

    var body: some View {
        DashboardCardView(title: "Storico controllo olio") {
            if records.isEmpty {
                DashboardEmptyStateView(state: .init(
                    title: "Nessun controllo nel periodo",
                    message: "I controlli salvati appariranno qui con punto olio, stato, valore, azione e operatore.",
                    actionTitle: nil
                ))
            } else {
                VStack(spacing: 10) {
                    ForEach(records) { record in
                        HStack(alignment: .top, spacing: 12) {
                            if let data = record.nonCompliancePhotoData,
                               let thumb = HACCPZoomablePhotoThumbnail(data: data, size: 52, zoomTitle: record.oilPointNameSnapshot) {
                                thumb
                            }
                            Circle()
                                .fill(color(for: record.oilStatus))
                                .frame(width: 10, height: 10)
                                .padding(.top, 6)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(record.oilPointNameSnapshot)
                                    .font(.headline)
                                    .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                                Text(record.checkedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                Text("\(record.oilStatus.label) · \(record.oilAction.label)")
                                    .font(.caption)
                                    .foregroundColor(color(for: record.oilStatus))
                                Text("Valore: \(polarText(record)) · Temperatura: \(temperatureText(record)) · Operatore: \(record.createdByNameSnapshot)")
                                    .font(.caption2)
                                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                if let notes = record.notes, !notes.isEmpty {
                                    Text("Note: \(notes)")
                                        .font(.caption2)
                                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                }
                            }
                            Spacer()
                            if canDelete {
                                Button("Elimina", role: .destructive) {
                                    onDelete(record)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(10)
                        .background(ThemeManager.shared.colorSurface)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    private func polarText(_ record: OilControlRecord) -> String {
        record.effectivePolarCompoundsValue.map { String(format: "%.1f%%", $0) } ?? "—"
    }

    private func temperatureText(_ record: OilControlRecord) -> String {
        record.temperature.map { String(format: "%.1f °C", $0) } ?? "—"
    }

    private func color(for status: OilStatus) -> Color {
        switch status {
        case .conforme: return ThemeManager.shared.colorSuccess
        case .daMonitorare: return ThemeManager.shared.colorWarning
        case .daSostituire: return ThemeManager.shared.colorWarning
        case .nonConforme: return ThemeManager.shared.colorError
        }
    }
}
