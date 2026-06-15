//
//  DefrostRecordCardView.swift
//

import SwiftUI

struct DefrostRecordCardView: View {
    let record: DefrostRecord
    var showCompleteAction: Bool = false
    var elapsedNow: Date = Date()
    var onComplete: (() -> Void)?

    @Environment(\.theme) private var theme

    private var isActiveProcess: Bool {
        record.isActive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.productName)
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colorTextPrimary)
                    if let lot = record.lotNumber, !lot.isEmpty {
                        Text("Lotto \(lot)")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                    }
                }
                Spacer()
                statusBadge
            }

            HStack(spacing: 16) {
                infoColumn(icon: "snowflake", title: "Metodo", value: record.method)
                infoColumn(icon: "clock", title: "Inizio", value: record.startAt.formatted(date: .abbreviated, time: .shortened))
            }

            if isActiveProcess {
                HStack {
                    infoColumn(
                        icon: "timer",
                        title: "Durata",
                        value: DefrostDurationFormatter.format(since: record.startAt, now: elapsedNow)
                    )
                    Spacer()
                }
            }

            HStack {
                Label(record.createdByNameSnapshot, systemImage: "person.fill")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                Spacer()
                if record.traceabilityItemId != nil {
                    Label("Tracciato", systemImage: "link")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorInfo)
                }
            }

            if showCompleteAction, let onComplete {
                PrimaryButton(title: "Termina decongelamento", icon: "checkmark.circle.fill", action: onComplete)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .fill(theme.colorSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .stroke(borderColor.opacity(0.5), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch record.displayStatus() {
        case .inProgress:
            HACCPBadge(title: DefrostStatus.inProgress.label, style: .info)
        case .delayed:
            HACCPBadge(title: DefrostStatus.delayed.label, style: .warning)
        case .completed:
            HACCPBadge(title: DefrostStatus.completed.label, style: .conforme)
        case .completedWithCriticality:
            HACCPBadge(title: DefrostStatus.completedWithCriticality.label, style: .nonConforme)
        case .cancelled:
            HACCPBadge(title: DefrostStatus.cancelled.label, style: .neutral)
        }
    }

    private var borderColor: Color {
        switch record.displayStatus() {
        case .delayed: return theme.colorWarning
        case .completedWithCriticality: return theme.colorError
        default: return theme.colorDivider
        }
    }

    private func infoColumn(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.colorTextSecondary)
            Text(value)
                .font(theme.typography.subheadline)
                .foregroundStyle(theme.colorTextPrimary)
        }
    }
}
