//
//  HACCPReportEngineCard.swift
//  HACCP Manager — Report Engine
//
//  Banner enterprise-grade per la dashboard "Documenti". Mostra in modo
//  professionale lo stato del motore: report totali, conformità media,
//  alert temperatura, non conformità aperte, stato sync iCloud, ultimo run.
//
//  Token-driven: usa `ThemeManager` per ogni colore/spaziatura/animazione,
//  così segue il tema scelto dall'utente (Dark Pro, Midnight Blue, ...).
//

import SwiftUI

struct HACCPReportEngineCard: View {
    let stats: HACCPReportEngineStats
    let lastRunSummary: String
    let isRunning: Bool
    let onRunNow: () -> Void

    @Environment(\.theme) private var theme

    init(
        stats: HACCPReportEngineStats,
        lastRunSummary: String,
        isRunning: Bool,
        onRunNow: @escaping () -> Void
    ) {
        self.stats = stats
        self.lastRunSummary = lastRunSummary
        self.isRunning = isRunning
        self.onRunNow = onRunNow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                    HStack(spacing: theme.spacing.sm) {
                        Image(systemName: "shield.lefthalf.filled")
                            .foregroundStyle(theme.colorInfo)
                        Text("HACCP Report Engine")
                            .font(theme.typography.headline)
                            .foregroundStyle(theme.colorTextPrimary)
                    }
                    Text("Automazione, immutabilità e tracciabilità totale.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
                Spacer()
                conformityBadge
            }

            statsGrid

            HStack(alignment: .center, spacing: theme.spacing.md) {
                VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                    Text(lastRunSummary.isEmpty ? "Nessuna esecuzione recente." : lastRunSummary)
                        .font(theme.typography.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                    if let last = stats.lastGeneratedAt {
                        Text("Ultimo PDF generato: \(last.formatted(date: .abbreviated, time: .shortened))")
                            .font(theme.typography.caption2)
                            .foregroundStyle(theme.colorTextSecondary)
                    }
                }
                Spacer()
                Button(action: onRunNow) {
                    HStack(spacing: theme.spacing.xs) {
                        if isRunning {
                            ProgressView().tint(theme.colorTextOnPrimary).scaleEffect(0.7)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(isRunning ? "In esecuzione…" : "Esegui ora")
                    }
                    .font(theme.typography.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(theme.colorInfo)
                .disabled(isRunning)
            }
        }
        .themedCard(theme)
    }

    // MARK: - Subviews

    private var conformityBadge: some View {
        let color = Color(hex: stats.conformityLevel.trafficLightHex)
        return HStack(spacing: theme.spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(stats.conformityPercent)%")
                .font(theme.typography.caption.weight(.bold))
                .foregroundStyle(theme.colorTextPrimary)
            Text(stats.conformityLevel.label)
                .font(theme.typography.caption2)
                .foregroundStyle(theme.colorTextSecondary)
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.sm)
        .background(theme.colorSurfaceElevated.opacity(0.6))
        .clipShape(Capsule())
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: theme.spacing.sm)],
                  spacing: theme.spacing.sm) {
            statTile(icon: "doc.text.fill",
                     title: "Report totali",
                     value: "\(stats.totalReports)",
                     color: theme.colorInfo)
            statTile(icon: "sun.max.fill",
                     title: "Generati oggi",
                     value: "\(stats.generatedToday)",
                     color: theme.colorWarning)
            statTile(icon: "exclamationmark.triangle.fill",
                     title: "Non conformità aperte",
                     value: "\(stats.openNonConformities)",
                     color: stats.openNonConformities == 0 ? theme.colorSuccess : theme.colorWarning)
            statTile(icon: "thermometer.medium",
                     title: "Alert temperatura",
                     value: "\(stats.temperatureAlerts)",
                     color: stats.temperatureAlerts == 0 ? theme.colorSuccess : theme.colorError)
            statTile(icon: "icloud.fill",
                     title: "Sincronizzati",
                     value: "\(stats.syncedToCloud)",
                     color: theme.colorInfo)
            statTile(icon: "icloud.slash.fill",
                     title: "In attesa cloud",
                     value: "\(stats.pendingCloudSync)",
                     color: stats.pendingCloudSync == 0 ? theme.colorSuccess : theme.colorTextSecondary)
        }
    }

    private func statTile(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            HStack(spacing: theme.spacing.xs) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(theme.typography.caption)
                Text(title)
                    .font(theme.typography.caption2)
                    .foregroundStyle(theme.colorTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            Text(value)
                .font(theme.typography.title3.weight(.bold))
                .foregroundStyle(theme.colorTextPrimary)
        }
        .padding(theme.spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colorSurfaceElevated.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerSmall, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerSmall, style: .continuous))
    }
}
