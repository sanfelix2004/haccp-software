//
//  TraceabilityRecordDetailSheet.swift
//

import SwiftUI

struct TraceabilityRecordDetailSheet: View {
    let record: TraceabilityRecord
    let display: TraceabilityRecordDisplay
    var photoBytes: [Data] = []
    let associatedProductions: [Production]
    let ingredientCountByProductionId: [UUID: Int]
    let linkedIngredientCount: Int
    let defrostRecords: [DefrostRecord]
    let auditLogs: [TraceabilityLog]
    let productionsById: [UUID: Production]
    let canDeleteRecords: Bool
    let hasExistingLabel: Bool
    let masterUser: LocalUser?
    let onAssociate: () -> Void
    let onLabel: () -> Void
    let onNonCompliant: () -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void

    @Environment(\.theme) private var theme
    @State private var showMasterDeleteAuth = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.sectionSpacing) {
                    if let production = associatedProductions.first {
                        productionContextBanner(production)
                    }
                    headerBlock
                    if !photoBytes.isEmpty {
                        photosCard
                    }
                    infoCard
                    if !associatedProductions.isEmpty {
                        productionsCard
                    }
                    if !auditLogs.isEmpty {
                        timelineCard
                    }
                    if !defrostRecords.isEmpty {
                        defrostCard
                    }
                    if record.isNonCompliant {
                        nonComplianceCard
                    }
                    actionsCard
                }
                .padding(theme.spacing.screenPadding + 8)
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle(display.productName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi", action: onDismiss)
                }
            }
            .fullScreenCover(isPresented: $showMasterDeleteAuth) {
                if let masterUser {
                    MasterAuthOverlay(
                        master: masterUser,
                        operation: .deleteTraceabilityEntry,
                        onAuthorized: {
                            showMasterDeleteAuth = false
                            onDelete()
                        },
                        onCancel: {
                            showMasterDeleteAuth = false
                        }
                    ) { EmptyView() }
                }
            }
        }
    }

    private var photosCard: some View {
        DashboardCardView(
            title: "Documentazione fotografica",
            subtitle: photoBytes.count == 1 ? "1 foto" : "\(photoBytes.count) foto"
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(photoBytes.enumerated()), id: \.offset) { index, data in
                        if let thumb = HACCPZoomablePhotoThumbnail(
                            data: data,
                            size: 120,
                            zoomTitle: "Foto \(index + 1) — \(display.productName)"
                        ) {
                            thumb
                        }
                    }
                }
            }
        }
    }

    private func productionContextBanner(_ production: Production) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.colorPrimary)
                .frame(width: 44, height: 44)
                .background(theme.colorPrimary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(production.name)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                Text("Piatto di produzione")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var headerBlock: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "shippingbox.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(theme.colorPrimary)
                .frame(width: 56, height: 56)
                .background(theme.colorPrimary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HACCPBadge(title: display.statusLabel, style: display.badgeStyle)
                Text("Ricevuto \(display.receivedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                if display.productionCount > 0 {
                    Label(
                        TraceabilityCountLabel.piattiEAlimenti(
                            productionCount: display.productionCount,
                            ingredientCount: display.linkedIngredientCount
                        ),
                        systemImage: "link"
                    )
                    .font(theme.typography.caption.weight(.semibold))
                    .foregroundStyle(theme.colorSuccess)
                } else if display.needsProductionLink {
                    Label("Da associare a un piatto", systemImage: "link.badge.plus")
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(theme.colorPrimary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var infoCard: some View {
        DashboardCardView(title: "Scheda prodotto", subtitle: "Dati HACCP") {
            VStack(spacing: 10) {
                detailRow(
                    display.isProductionLot ? "Lotto produzione" : "Lotto",
                    display.lot
                )
                detailRow("Fornitore", display.supplier)
                if let category = display.category {
                    detailRow("Categoria", category)
                }
                detailRow(
                    "Registrato",
                    display.receivedAt.formatted(date: .abbreviated, time: .shortened)
                )
            }
        }
    }

    private var productionsCard: some View {
        DashboardCardView(
            title: "Piatti collegati",
            subtitle: TraceabilityCountLabel.piattiEAlimenti(
                productionCount: associatedProductions.count,
                ingredientCount: linkedIngredientCount
            )
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(associatedProductions) { production in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(theme.colorSuccess)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(production.name)
                                .font(theme.typography.subheadline)
                                .foregroundStyle(theme.colorTextPrimary)
                            Text(
                                TraceabilityCountLabel.alimenti(
                                    ingredientCountByProductionId[production.id] ?? 0
                                )
                            )
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                        }
                    }
                }
            }
        }
    }

    private var timelineCard: some View {
        DashboardCardView(title: "Cronologia", subtitle: "Audit HACCP") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(auditLogs, id: \.id) { log in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: timelineIcon(for: log.actionType))
                            .font(.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(timelineTitle(for: log))
                                .font(theme.typography.caption.weight(.semibold))
                            Text("\(log.operatorName) · \(log.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                .font(theme.typography.caption2)
                                .foregroundStyle(theme.colorTextSecondary)
                        }
                    }
                }
            }
        }
    }

    private var defrostCard: some View {
        DashboardCardView(title: "Decongelamento", subtitle: "Utilizzi registrati") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(defrostRecords) { defrost in
                    let duration = defrost.endAt.map {
                        ProcessElapsedFormatter.formatReadable(since: defrost.startAt, until: $0)
                    } ?? ProcessElapsedFormatter.format(since: defrost.startAt)
                    Text("\(defrost.method) · \(defrost.defrostStatus.label) · Durata \(duration)")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorInfo)
                }
            }
        }
    }

    private var nonComplianceCard: some View {
        DashboardCardView(title: "Non conformità", subtitle: "Criticità registrata") {
            VStack(alignment: .leading, spacing: 8) {
                if let note = record.nonComplianceNote, !note.isEmpty {
                    Label(note, systemImage: "exclamationmark.triangle.fill")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorWarning)
                }
                if let action = record.nonComplianceCorrectiveAction, !action.isEmpty {
                    Label(action, systemImage: "wrench.and.screwdriver.fill")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }
        }
    }

    private var actionsCard: some View {
        DashboardCardView(title: "Azioni", subtitle: "Gestione in cucina") {
            VStack(spacing: 12) {
                PrimaryButton(
                    title: display.needsProductionLink ? "Associa a piatto" : "Modifica collegamenti",
                    icon: "link"
                ) {
                    onAssociate()
                }
                .disabled(!display.isActionable && !record.isNonCompliant)

                if record.productStatus != .rejected {
                    SecondaryButton(
                        title: hasExistingLabel ? "Vedi etichetta HACCP" : "Crea etichetta HACCP",
                        icon: "tag.fill",
                        action: onLabel
                    )
                }

                SecondaryButton(title: "Segna non conforme", icon: "exclamationmark.triangle.fill", action: onNonCompliant)
                    .disabled(record.productStatus == .rejected)

                if canDeleteRecords {
                    SecondaryButton(title: "Elimina scheda", icon: "trash") {
                        showMasterDeleteAuth = true
                    }
                }

                if !display.isActionable {
                    Text("Prodotto non più associabile. Per scadenze e ritiro usa Controllo scadenze.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func detailRow(_ title: String, _ value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
            Spacer()
            Text(value)
                .font(theme.typography.subheadline.weight(.semibold))
                .foregroundStyle(highlight ? theme.colorWarning : theme.colorTextPrimary)
        }
    }

    private func timelineIcon(for action: TraceabilityActionType) -> String {
        switch action {
        case .created: return "plus.circle"
        case .linkedToProduction: return "link"
        case .expired: return "clock.badge.exclamationmark"
        case .rejected: return "xmark.circle"
        case .nonCompliance: return "exclamationmark.triangle"
        case .withdrawn: return "archivebox"
        case .expiryRegistered: return "calendar.badge.clock"
        case .archivedFromExpiryControl: return "archivebox.fill"
        case .removedFromHistory: return "eye.slash"
        }
    }

    private func timelineTitle(for log: TraceabilityLog) -> String {
        switch log.actionType {
        case .created: return "Lotto registrato"
        case .linkedToProduction:
            if let name = log.linkedProductionDisplayName(productionsById: productionsById) {
                return "Collegato a \(name)"
            }
            return "Collegato a produzione"
        case .expired: return "Marcato scaduto"
        case .rejected: return "Respinto"
        case .nonCompliance: return "Non conformità"
        case .withdrawn: return log.detail ?? "Ritirato / scartato"
        case .expiryRegistered: return log.detail ?? "Scadenza registrata"
        case .archivedFromExpiryControl: return log.detail ?? "Rimosso da controllo scadenze"
        case .removedFromHistory: return log.detail ?? "Nascosto dallo storico (Documenti ok)"
        }
    }
}
