//
//  ICloudArchiveStatusCard.swift
//  Stato backup mensile su iCloud Drive nell'archivio Documenti.
//

import SwiftUI

struct ICloudArchiveStatusCard: View {
    let restaurantName: String
    let syncedCount: Int
    let pendingCount: Int
    let totalPdfCount: Int
    let isICloudAvailable: Bool
    let isSyncEnabled: Bool
    let lastMonthlySyncText: String
    let lastActivity: String
    let contactEmail: String
    let isSyncing: Bool
    let onSyncNow: () -> Void

    @Environment(\.theme) private var theme
    @State private var pulseSync = false

    private var syncProgress: Double {
        guard totalPdfCount > 0 else { return isSyncing ? 0.35 : 0 }
        return Double(syncedCount) / Double(totalPdfCount)
    }

    private var statusTitle: String {
        if !isSyncEnabled { return "Backup disattivato" }
        if !isICloudAvailable { return "iCloud non disponibile" }
        if isSyncing { return "Sincronizzazione in corso…" }
        if pendingCount > 0 { return "\(pendingCount) PDF da copiare" }
        if totalPdfCount > 0 { return "Archivio aggiornato" }
        return "In attesa dei PDF mensili"
    }

    private var statusSubtitle: String {
        if !isSyncEnabled {
            return "Collega iCloud in Impostazioni → Profilo Utente."
        }
        if !isICloudAvailable {
            return "Verifica account iCloud e iCloud Drive sul dispositivo."
        }
        return "Ultimo backup mensile: \(lastMonthlySyncText)"
    }

    private var accentColor: Color {
        if !isSyncEnabled || !isICloudAvailable { return theme.colorWarning }
        if pendingCount > 0 { return theme.colorInfo }
        return theme.colorSuccess
    }

    var body: some View {
        GlassCard(elevated: true) {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                headerRow

                syncProgressStrip

                statsRow

                if !contactEmail.isEmpty {
                    metaRow(icon: "envelope.fill", text: contactEmail)
                }
                if !lastActivity.isEmpty, !isSyncing {
                    metaRow(icon: "clock.arrow.circlepath", text: lastActivity)
                }

                Text("I PDF si aggiornano con i dati HACCP e si copiano su iCloud dalla schermata Documenti.")
                    .font(theme.typography.caption2)
                    .foregroundStyle(theme.colorTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                syncButton
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseSync = isSyncing
            }
        }
        .onChange(of: isSyncing) { _, syncing in
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseSync = syncing
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.14))
                    .frame(width: 52, height: 52)
                Image(systemName: isICloudAvailable ? "icloud.fill" : "icloud.slash")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .scaleEffect(pulseSync ? 1.06 : 1)
            }

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text("Backup iCloud")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                Text(restaurantName)
                    .font(theme.typography.caption.weight(.semibold))
                    .foregroundStyle(theme.colorTextSecondary)
                Text(statusTitle)
                    .font(theme.typography.subheadline.weight(.semibold))
                    .foregroundStyle(accentColor)
                Text(statusSubtitle)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var syncProgressStrip: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            HStack {
                Text("Copertura cloud")
                    .font(theme.typography.caption2.weight(.semibold))
                    .foregroundStyle(theme.colorTextSecondary)
                Spacer()
                Text("\(syncedCount)/\(totalPdfCount) PDF")
                    .font(theme.typography.caption2.weight(.bold))
                    .foregroundStyle(theme.colorTextPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.colorSurfaceElevated.opacity(0.9))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.85), accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * syncProgress))
                        .animation(theme.spring, value: syncProgress)
                }
            }
            .frame(height: 8)
        }
    }

    private var statsRow: some View {
        HStack(spacing: theme.spacing.sm) {
            miniStat(label: "In archivio", value: "\(totalPdfCount)", icon: "doc.richtext.fill", color: theme.colorInfo)
            miniStat(label: "Su iCloud", value: "\(syncedCount)", icon: "icloud.fill", color: theme.colorSuccess)
            miniStat(label: "In coda", value: "\(pendingCount)", icon: "arrow.up.circle.fill", color: pendingCount == 0 ? theme.colorSuccess : theme.colorWarning)
        }
    }

    private func miniStat(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xxs) {
            HStack(spacing: theme.spacing.xxs) {
                Image(systemName: icon)
                    .font(theme.typography.caption2)
                    .foregroundStyle(color)
                Text(label)
                    .font(theme.typography.caption2)
                    .foregroundStyle(theme.colorTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(value)
                .font(theme.typography.title3.weight(.bold))
                .foregroundStyle(theme.colorTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.sm)
        .background(theme.colorSurfaceElevated.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerSmall, style: .continuous))
    }

    private func metaRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: theme.spacing.sm) {
            Image(systemName: icon)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
                .frame(width: 18)
            Text(text)
                .font(theme.typography.caption2)
                .foregroundStyle(theme.colorTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var syncButton: some View {
        Button(action: onSyncNow) {
            HStack(spacing: theme.spacing.sm) {
                if isSyncing {
                    ProgressView()
                        .tint(theme.colorTextOnPrimary)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath.icloud")
                        .font(.headline.weight(.semibold))
                }
                Text(isSyncing ? "Sincronizzazione…" : "Sincronizza ora")
                    .font(theme.typography.headline)
            }
            .foregroundStyle(theme.colorTextOnPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: theme.spacing.buttonMinHeight)
            .background(
                RoundedRectangle(cornerRadius: theme.spacing.buttonCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.colorInfo, theme.colorInfo.opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: theme.shadows.glowPrimary.color.opacity(0.35), radius: 8, y: 4)
        }
        .buttonStyle(PremiumPressButtonStyle())
        .disabled(isSyncing || !isSyncEnabled || !isICloudAvailable)
        .opacity(isSyncing || !isSyncEnabled || !isICloudAvailable ? 0.55 : 1)
        .accessibilityLabel(isSyncing ? "Sincronizzazione iCloud in corso" : "Sincronizza archivio su iCloud")
    }
}
