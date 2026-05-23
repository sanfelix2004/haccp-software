//
//  ActiveBlastChillingListSheet.swift
//  Popup con tutti gli abbattimenti attivi — termina manualmente.
//

import SwiftUI

struct ActiveBlastChillingListSheet: View {
    @EnvironmentObject var blastManager: ActiveBlastChillingManager
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    let onTerminate: (UUID) -> Void
    let onCancelProcess: (UUID) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                if blastManager.activeSnapshots.isEmpty {
                    ContentUnavailableView(
                        "Nessun abbattimento attivo",
                        systemImage: "snowflake",
                        description: Text("Avvia un nuovo abbattimento dalla sezione Abbattimento in negativo.")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(blastManager.activeSnapshots) { snapshot in
                            blastRow(snapshot)
                        }
                    }
                    .padding(theme.spacing.screenPadding + 8)
                }
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle("Abbattimenti in corso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func blastRow(_ snapshot: ActiveBlastSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.productionName)
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colorTextPrimary)
                    Text(snapshot.categoryName)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
                Spacer()
                Text(snapshot.formattedElapsed(at: blastManager.now))
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundStyle(snapshot.isOverRecommended(at: blastManager.now) ? theme.colorWarning : Color.cyan)
            }

            Label("Inizio \(snapshot.startedAt.formatted(date: .omitted, time: .shortened))", systemImage: "clock")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)

            Label(
                String(format: "%.1f°C → target %.1f°C", snapshot.initialTemperature, snapshot.targetTemperature),
                systemImage: "thermometer.snowflake"
            )
            .font(theme.typography.caption)
            .foregroundStyle(theme.colorTextSecondary)

            if snapshot.isOverRecommended(at: blastManager.now) {
                Label("Durata oltre il tempo consigliato", systemImage: "exclamationmark.triangle.fill")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorWarning)
            }

            HStack(spacing: 10) {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onTerminate(snapshot.id)
                    }
                } label: {
                    Label("Termina abbattimento", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button("Annulla", role: .destructive) {
                    onCancelProcess(snapshot.id)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .fill(theme.colorSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .stroke(
                    snapshot.isOverRecommended(at: blastManager.now) ? theme.colorWarning.opacity(0.5) : theme.colorDivider,
                    lineWidth: 1
                )
        )
    }
}
