//
//  ChecklistRunCard.swift
//

import SwiftUI

struct ChecklistRunCard: View {
    let run: ChecklistRun
    let summary: ChecklistProgressSummary
    var category: ChecklistCategory?
    var frequency: ChecklistFrequency?
    let onTap: () -> Void

    @Environment(\.theme) private var theme

    private let scheduleService = ChecklistScheduleService()

    private var isOverdueToday: Bool {
        guard let frequency else { return run.status == .overdue }
        return scheduleService.isOverdueForDashboard(run: run, frequency: frequency)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(theme.colorPrimary.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: category?.systemImage ?? "checklist")
                            .foregroundStyle(theme.colorPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(run.templateTitleSnapshot)
                            .font(theme.typography.headline)
                            .foregroundStyle(theme.colorTextPrimary)
                            .multilineTextAlignment(.leading)
                        if let frequency {
                            Label(frequency.label, systemImage: frequency.systemImage)
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary)
                        }
                        if let dueAt = run.dueAt {
                            Label(
                                dueLabel(dueAt),
                                systemImage: isOverdueToday ? "clock.badge.exclamationmark" : "clock"
                            )
                            .font(theme.typography.caption)
                            .foregroundStyle(isOverdueToday ? theme.colorWarning : theme.colorTextSecondary)
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 6) {
                        HACCPBadge(title: statusTitle, style: run.status.badgeStyle, showIcon: false)
                        if summary.hasFailures {
                            HACCPBadge(title: "Criticità", style: .nonConforme, showIcon: true)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(summary.completed)/\(summary.total) attività")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                        Spacer()
                        Text("\(summary.progressPercentage)%")
                            .font(theme.typography.caption.weight(.semibold))
                            .foregroundStyle(theme.colorTextPrimary)
                    }
                    ProgressView(value: Double(summary.progressPercentage), total: 100)
                        .tint(progressTint)
                }
            }
            .padding(14)
            .background(theme.colorSurface)
            .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                    .stroke(borderColor.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(PremiumPressButtonStyle())
    }

    private var statusTitle: String {
        if summary.progressPercentage >= 100 { return "Completata" }
        if summary.progressPercentage <= 0 { return run.status.label }
        return "\(summary.progressPercentage)%"
    }

    private var progressTint: Color {
        if summary.hasFailures { return theme.colorError }
        if summary.progressPercentage >= 100 { return theme.colorSuccess }
        if summary.progressPercentage >= 50 { return theme.colorWarning }
        return theme.colorInfo
    }

    private var borderColor: Color {
        if isOverdueToday || summary.hasFailures { return theme.colorWarning }
        return theme.colorDivider
    }

    private func dueLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if isOverdueToday {
            return "In ritardo · \(date.formatted(date: .omitted, time: .shortened))"
        }
        if calendar.isDateInToday(date) {
            return "Scadenza oggi \(date.formatted(date: .omitted, time: .shortened))"
        }
        return "Scadenza \(date.formatted(date: .abbreviated, time: .shortened))"
    }
}
