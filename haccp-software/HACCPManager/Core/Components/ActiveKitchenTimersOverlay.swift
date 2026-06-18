//
//  ActiveKitchenTimersOverlay.swift
//  Bubble decongelamento + abbattimento impilati (non sovrapposti).
//

import SwiftUI
import SwiftData

struct ActiveKitchenTimersOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var defrostManager: ActiveDefrostManager
    @EnvironmentObject var blastManager: ActiveBlastChillingManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @Query private var users: [LocalUser]

    @State private var defrostCancelTargetId: UUID?
    @State private var blastCancelTargetId: UUID?
    @State private var showDefrostCancelConfirm = false
    @State private var showBlastCancelConfirm = false

    private var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }

    private var hasAnyTimer: Bool {
        defrostManager.hasActiveDefrosts || blastManager.hasActiveBlasts
    }

    var body: some View {
        Group {
            if hasAnyTimer {
                timerStack
            }
        }
        .animation(theme.spring, value: hasAnyTimer)
        .defrostTimerSheets(
            appState: appState,
            modelContext: modelContext,
            currentUser: currentUser,
            cancelTargetId: $defrostCancelTargetId,
            showCancelConfirm: $showDefrostCancelConfirm
        )
        .blastTimerSheets(
            appState: appState,
            modelContext: modelContext,
            cancelTargetId: $blastCancelTargetId,
            showCancelConfirm: $showBlastCancelConfirm
        )
    }

    private var timerStack: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if defrostManager.hasActiveDefrosts {
                defrostBubble
            }
            if blastManager.hasActiveBlasts {
                blastBubble
            }
        }
        .padding(.trailing, 16)
        .padding(.bottom, 24)
    }

    private var defrostBubble: some View {
        Button {
            defrostManager.showActiveListSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "drop.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(red: 0.4, green: 0.75, blue: 1.0))
                VStack(alignment: .leading, spacing: 2) {
                    if defrostManager.activeSnapshots.count == 1,
                       let primary = defrostManager.primarySnapshot {
                        Text("Decongelamento")
                            .font(theme.typography.headline)
                            .foregroundStyle(theme.colorTextOnPrimary)
                        LiveProcessDurationText(
                            since: primary.startAt,
                            font: theme.typography.caption.monospacedDigit(),
                            color: theme.colorTextOnPrimary.opacity(0.85)
                        )
                    } else {
                        Text(defrostManager.collapsedTitle)
                            .font(theme.typography.headline)
                            .foregroundStyle(theme.colorTextOnPrimary)
                        Text(defrostManager.collapsedSubtitle)
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextOnPrimary.opacity(0.85))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.45, blue: 0.72),
                                Color(red: 0.08, green: 0.28, blue: 0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color(red: 0.5, green: 0.85, blue: 1.0).opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var blastBubble: some View {
        Button {
            blastManager.showActiveListSheet = true
        } label: {
            TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                HStack(spacing: 10) {
                    Image(systemName: "snowflake")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.cyan.opacity(0.95))
                    VStack(alignment: .leading, spacing: 2) {
                        if blastManager.activeSnapshots.count == 1,
                           let primary = blastManager.primarySnapshot {
                            Text("Abbattimento")
                                .font(theme.typography.headline)
                                .foregroundStyle(theme.colorTextOnPrimary)
                            LiveProcessDurationText(
                                since: primary.startedAt,
                                font: theme.typography.caption.monospacedDigit(),
                                color: theme.colorTextOnPrimary.opacity(0.85)
                            )
                        } else {
                            Text(blastManager.collapsedTitle)
                                .font(theme.typography.headline)
                                .foregroundStyle(theme.colorTextOnPrimary)
                            Text(blastManager.collapsedSubtitle)
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextOnPrimary.opacity(0.85))
                        }
                    }
                    if blastManager.activeSnapshots.contains(where: { $0.isOverRecommended(at: timeline.date) }) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(theme.colorWarning)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.colorPrimary.opacity(0.95),
                                    Color(red: 0.15, green: 0.35, blue: 0.75)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.cyan.opacity(0.45), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 12, y: 6)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sheet moduli

private extension View {
    func defrostTimerSheets(
        appState: AppState,
        modelContext: ModelContext,
        currentUser: LocalUser?,
        cancelTargetId: Binding<UUID?>,
        showCancelConfirm: Binding<Bool>
    ) -> some View {
        modifier(DefrostTimerSheetsModifier(
            appState: appState,
            modelContext: modelContext,
            currentUser: currentUser,
            cancelTargetId: cancelTargetId,
            showCancelConfirm: showCancelConfirm
        ))
    }

    func blastTimerSheets(
        appState: AppState,
        modelContext: ModelContext,
        cancelTargetId: Binding<UUID?>,
        showCancelConfirm: Binding<Bool>
    ) -> some View {
        modifier(BlastTimerSheetsModifier(
            appState: appState,
            modelContext: modelContext,
            cancelTargetId: cancelTargetId,
            showCancelConfirm: showCancelConfirm
        ))
    }
}

private struct DefrostTimerSheetsModifier: ViewModifier {
    @EnvironmentObject var defrostManager: ActiveDefrostManager

    let appState: AppState
    let modelContext: ModelContext
    let currentUser: LocalUser?
    @Binding var cancelTargetId: UUID?
    @Binding var showCancelConfirm: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $defrostManager.showActiveListSheet) {
                ActiveDefrostListSheet(
                    onTerminate: { defrostManager.recordIdPendingComplete = $0 },
                    onCancelProcess: { id in
                        cancelTargetId = id
                        showCancelConfirm = true
                    }
                )
                .environmentObject(defrostManager)
            }
            .sheet(isPresented: defrostCompletePresented) {
                defrostCompleteSheetContent
            }
            .confirmationDialog(
                "Annullare decongelamento?",
                isPresented: $showCancelConfirm,
                titleVisibility: .visible
            ) {
                Button("Annulla decongelamento", role: .destructive) {
                    guard let id = cancelTargetId,
                          let rid = appState.activeRestaurantId,
                          let record = defrostManager.fetchRecord(id: id, restaurantId: rid, context: modelContext) else { return }
                    defrostManager.cancel(record: record, context: modelContext)
                    defrostManager.showActiveListSheet = false
                    cancelTargetId = nil
                }
                Button("Indietro", role: .cancel) {}
            } message: {
                Text("Il decongelamento verrà chiuso come annullato e resterà nello storico.")
            }
            .alert("Decongelamento", isPresented: defrostErrorPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(defrostManager.errorMessage ?? "")
            }
    }

    @ViewBuilder
    private var defrostCompleteSheetContent: some View {
        if let record = defrostCompleteRecord, let user = currentUser {
            DefrostCompleteSheet(
                record: record,
                user: user,
                criticalities: defrostManager.fetchCriticalities(
                    recordId: record.id,
                    restaurantId: record.restaurantId,
                    context: modelContext
                ),
                onCompleted: {
                    defrostManager.recordIdPendingComplete = nil
                    defrostManager.refresh(
                        context: modelContext,
                        restaurantId: appState.activeRestaurantId
                    )
                },
                onCancel: { defrostManager.recordIdPendingComplete = nil }
            )
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    defrostManager.recordIdPendingComplete = nil
                }
        }
    }

    private var defrostCompletePresented: Binding<Bool> {
        Binding(
            get: { defrostManager.recordIdPendingComplete != nil },
            set: { if !$0 { defrostManager.recordIdPendingComplete = nil } }
        )
    }

    private var defrostCompleteRecord: DefrostRecord? {
        guard let id = defrostManager.recordIdPendingComplete,
              let rid = appState.activeRestaurantId else { return nil }
        return defrostManager.fetchRecord(id: id, restaurantId: rid, context: modelContext)
    }

    private var defrostErrorPresented: Binding<Bool> {
        Binding(
            get: { defrostManager.errorMessage != nil },
            set: { if !$0 { defrostManager.errorMessage = nil } }
        )
    }
}

private struct BlastTimerSheetsModifier: ViewModifier {
    @EnvironmentObject var blastManager: ActiveBlastChillingManager

    let appState: AppState
    let modelContext: ModelContext
    @Binding var cancelTargetId: UUID?
    @Binding var showCancelConfirm: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $blastManager.showActiveListSheet) {
                ActiveBlastChillingListSheet(
                    onTerminate: { blastManager.recordIdPendingComplete = $0 },
                    onCancelProcess: { id in
                        cancelTargetId = id
                        showCancelConfirm = true
                    }
                )
                .environmentObject(blastManager)
            }
            .sheet(isPresented: blastCompletePresented) {
                blastCompleteSheetContent
            }
            .confirmationDialog(
                "Annullare abbattimento?",
                isPresented: $showCancelConfirm,
                titleVisibility: .visible
            ) {
                Button("Annulla abbattimento", role: .destructive) {
                    guard let id = cancelTargetId,
                          let rid = appState.activeRestaurantId,
                          let record = blastManager.fetchRecord(id: id, restaurantId: rid, context: modelContext) else { return }
                    blastManager.cancel(record: record, context: modelContext)
                    blastManager.showActiveListSheet = false
                    cancelTargetId = nil
                }
                Button("Indietro", role: .cancel) {}
            } message: {
                Text("L'abbattimento verrà chiuso come annullato e resterà nello storico.")
            }
            .alert("Abbattimento", isPresented: blastErrorPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(blastManager.errorMessage ?? "")
            }
    }

    @ViewBuilder
    private var blastCompleteSheetContent: some View {
        if let record = blastCompleteRecord {
            BlastChillingRecordSheet(
                production: blastManager.production(for: record),
                existingRecord: record,
                operatorName: record.createdByNameSnapshot,
                validationService: BlastChillingValidationService(),
                onCancel: { blastManager.recordIdPendingComplete = nil },
                onStart: { _, _, _ in },
                onComplete: { rec, endedAt, final, notes, action in
                    blastManager.complete(
                        record: rec,
                        endedAt: endedAt,
                        finalTemperature: final,
                        notes: notes,
                        correctiveAction: action,
                        context: modelContext
                    )
                }
            )
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    blastManager.recordIdPendingComplete = nil
                }
        }
    }

    private var blastCompletePresented: Binding<Bool> {
        Binding(
            get: { blastManager.recordIdPendingComplete != nil },
            set: { if !$0 { blastManager.recordIdPendingComplete = nil } }
        )
    }

    private var blastCompleteRecord: BlastChillingRecord? {
        guard let id = blastManager.recordIdPendingComplete,
              let rid = appState.activeRestaurantId else { return nil }
        return blastManager.fetchRecord(id: id, restaurantId: rid, context: modelContext)
    }

    private var blastErrorPresented: Binding<Bool> {
        Binding(
            get: { blastManager.errorMessage != nil },
            set: { if !$0 { blastManager.errorMessage = nil } }
        )
    }
}
