import SwiftUI

struct OilPointGridView: View {
    let points: [OilPoint]
    let records: [OilControlRecord]
    let selectedPointId: UUID?
    let onSelect: (OilPoint) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
            ForEach(points) { point in
                Button {
                    onSelect(point)
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(point.name)
                                .font(.headline)
                                .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                                .lineLimit(2)
                            Spacer()
                            Image(systemName: "drop.fill")
                                .foregroundColor(statusColor(for: point))
                        }
                        if let last = lastRecord(for: point) {
                            Text(last.oilStatus.label)
                                .font(.caption.weight(.bold))
                                .foregroundColor(statusColor(for: point))
                            Text(last.checkedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                        } else {
                            Text("Nessun controllo")
                                .font(.caption)
                                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
                    .padding(12)
                    .background(ThemeManager.shared.colorSurfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(selectedPointId == point.id ? ThemeManager.shared.colorPrimary : ThemeManager.shared.colorDivider, lineWidth: selectedPointId == point.id ? 2 : 1)
                    )
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func lastRecord(for point: OilPoint) -> OilControlRecord? {
        records
            .filter { $0.oilPointId == point.id }
            .sorted { $0.checkedAt > $1.checkedAt }
            .first
    }

    private func statusColor(for point: OilPoint) -> Color {
        switch lastRecord(for: point)?.oilStatus {
        case .conforme: return ThemeManager.shared.colorSuccess
        case .daMonitorare: return ThemeManager.shared.colorWarning
        case .daSostituire: return ThemeManager.shared.colorWarning
        case .nonConforme: return ThemeManager.shared.colorError
        case nil: return ThemeManager.shared.colorTextSecondary
        }
    }
}
