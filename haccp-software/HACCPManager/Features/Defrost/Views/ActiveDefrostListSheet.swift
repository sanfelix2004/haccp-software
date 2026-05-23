//
//  ActiveDefrostListSheet.swift
//  Popup con tutti i decongelamenti attivi — termina manualmente.
//

import SwiftUI

struct ActiveDefrostListSheet: View {
    @EnvironmentObject var defrostManager: ActiveDefrostManager
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    let onTerminate: (UUID) -> Void
    let onCancelProcess: (UUID) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                if defrostManager.activeSnapshots.isEmpty {
                    ContentUnavailableView(
                        "Nessun decongelamento attivo",
                        systemImage: "drop.fill",
                        description: Text("Avvia un nuovo decongelamento dalla sezione Decongelamento.")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(defrostManager.activeSnapshots) { snapshot in
                            defrostRow(snapshot)
                        }
                    }
                    .padding(theme.spacing.screenPadding + 8)
                }
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle("Decongelamenti in corso")
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

    private func defrostRow(_ snapshot: ActiveDefrostSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.productName)
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colorTextPrimary)
                    Text(snapshot.methodLabel)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                    if let lot = snapshot.lotNumber, !lot.isEmpty {
                        Text("Lotto \(lot)")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                    }
                }
                Spacer()
                Text(snapshot.formattedElapsed(at: defrostManager.now))
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundStyle(Color(red: 0.35, green: 0.7, blue: 1.0))
            }

            Label("Inizio \(snapshot.startAt.formatted(date: .omitted, time: .shortened))", systemImage: "clock")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)

            HStack(spacing: 10) {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onTerminate(snapshot.id)
                    }
                } label: {
                    Label("Termina decongelamento", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

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
                .stroke(theme.colorDivider, lineWidth: 1)
        )
    }
}
