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
    /// Stato operativo del piatto finito per produzione (Scaduto / Scartato / Usato…).
    var productionStatusById: [UUID: TraceabilityLotOperationalStatus.Presentation] = [:]
    let linkedIngredientCount: Int
    let defrostRecords: [DefrostRecord]
    let auditLogs: [TraceabilityLog]
    let productionsById: [UUID: Production]
    let canDeleteRecords: Bool
    let canEditRecords: Bool
    let hasExistingLabel: Bool
    let masterUser: LocalUser?
    let onAssociate: () -> Void
    let onLabel: () -> Void
    let onNonCompliant: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void

    @Environment(\.theme) private var theme
    @State private var showMasterDeleteAuth = false
    @State private var showMasterEditAuth = false

    private var lifecycle: TraceabilityLifecycleSummary {
        TraceabilityLifecycleSummary.build(
            record: record,
            logs: auditLogs,
            productionsById: productionsById
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.sectionSpacing) {
                    headerBlock
                    openingCard
                    if !photoBytes.isEmpty {
                        photosCard
                    }
                    associationsCard
                    closureCard
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
            .fullScreenCover(isPresented: $showMasterEditAuth) {
                if let masterUser {
                    MasterAuthOverlay(
                        master: masterUser,
                        operation: .privilegedAction,
                        onAuthorized: {
                            showMasterEditAuth = false
                            onEdit()
                        },
                        onCancel: {
                            showMasterEditAuth = false
                        }
                    ) { EmptyView() }
                }
            }
        }
    }

    private var headerBlock: some View {
        HStack(alignment: .top, spacing: 16) {
            if let first = photoBytes.first,
               let thumb = HACCPZoomablePhotoThumbnail(
                data: first,
                size: 56,
                zoomTitle: display.productName
               ) {
                thumb
            } else {
                Image(systemName: display.isProductionLot ? "fork.knife" : "shippingbox.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.colorPrimary)
                    .frame(width: 56, height: 56)
                    .background(theme.colorPrimary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                HACCPBadge(
                    title: lifecycle.closure.map { "Chiuso · \($0.outcome)" } ?? display.statusLabel,
                    style: lifecycle.closure != nil ? .neutral : display.badgeStyle
                )
                Text(lifecycle.createdLine)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                if let closureLine = lifecycle.closureLine {
                    Text(closureLine)
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(theme.colorWarning)
                } else if display.needsProductionLink {
                    Label("Da associare a un piatto", systemImage: "link.badge.plus")
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(theme.colorPrimary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var openingCard: some View {
        DashboardCardView(
            title: "1. Apertura lotto",
            subtitle: display.isProductionLot ? "Produzione finita" : "Alimento in ingresso"
        ) {
            VStack(spacing: 10) {
                detailRow("Creato il", lifecycle.createdAt.formatted(date: .abbreviated, time: .shortened))
                detailRow("Registrato da", lifecycle.createdBy)
                detailRow(lifecycle.lotLabel, lifecycle.lotValue)
                if !display.isProductionLot {
                    detailRow("Fornitore", lifecycle.supplier)
                }
                if let category = display.category {
                    detailRow("Categoria", category)
                }
                if let expiry = lifecycle.expiryDate {
                    detailRow("Scadenza", TraceabilityLifecycleSummary.fmtDate(expiry))
                } else {
                    detailRow("Scadenza", "Non indicata — usa al più presto", highlight: true)
                }
            }
        }
    }

    private var photosCard: some View {
        DashboardCardView(
            title: "2. Foto",
            subtitle: display.isProductionLot
                ? (photoBytes.count == 1 ? "Foto del piatto" : "\(photoBytes.count) foto del piatto")
                : (photoBytes.count == 1 ? "Foto etichetta / prodotto" : "\(photoBytes.count) foto")
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

    private var associationsCard: some View {
        DashboardCardView(
            title: "3. Associazioni",
            subtitle: lifecycle.associations.isEmpty && associatedProductions.isEmpty
                ? "Nessun piatto collegato"
                : TraceabilityCountLabel.piattiEAlimenti(
                    productionCount: max(associatedProductions.count, Set(lifecycle.associations.map(\.productionName)).count),
                    ingredientCount: linkedIngredientCount
                )
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if lifecycle.associations.isEmpty && associatedProductions.isEmpty {
                    Text(display.isProductionLot
                         ? "Questo è il piatto finito: gli ingredienti sono nei lotti collegati in Storia."
                         : "Non ancora associato a una produzione.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }

                ForEach(lifecycle.associations) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "link")
                            .foregroundStyle(theme.colorSuccess)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Associato a «\(item.productionName)»")
                                .font(theme.typography.subheadline.weight(.semibold))
                                .foregroundStyle(theme.colorTextPrimary)
                            Text("Il \(item.occurredAt.formatted(date: .abbreviated, time: .shortened)) da \(item.operatorName)")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary)
                            if let status = statusForAssociation(named: item.productionName) {
                                HACCPBadge(title: status.label, style: status.badgeStyle, showIcon: false)
                            }
                        }
                    }
                }

                // Fallback se ci sono produzioni senza log di associazione.
                if lifecycle.associations.isEmpty {
                    ForEach(associatedProductions) { production in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "fork.knife")
                                .foregroundStyle(theme.colorSuccess)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(production.name)
                                    .font(theme.typography.subheadline.weight(.semibold))
                                Text(
                                    TraceabilityCountLabel.alimenti(
                                        ingredientCountByProductionId[production.id] ?? 0
                                    )
                                )
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary)
                                if let status = productionStatusById[production.id] {
                                    HACCPBadge(title: status.label, style: status.badgeStyle, showIcon: false)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var closureCard: some View {
        DashboardCardView(
            title: "4. Chiusura",
            subtitle: lifecycle.closure == nil ? "Ancora in uso in cucina" : "Esito operativo"
        ) {
            if let closure = lifecycle.closure {
                VStack(spacing: 10) {
                    detailRow("Esito", closure.outcome)
                    detailRow("Quando", closure.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    detailRow("Operatore", closure.operatorName)
                    if let note = closure.note, !note.isEmpty {
                        detailRow("Motivazione", note)
                    }
                }
            } else if record.productStatus == .used || record.productStatus == .rejected {
                Text("Lotto chiuso (stato \(record.productStatus.label)). Dettaglio motivo non disponibile nei log.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            } else {
                Text("Non ancora terminato / scartato / scaduto. La chiusura si registra da Controllo scadenze e quantità.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            }
        }
    }

    private var timelineCard: some View {
        DashboardCardView(title: "Cronologia completa", subtitle: "Tutti gli eventi in ordine") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(auditLogs.sorted(by: { $0.timestamp > $1.timestamp }), id: \.id) { log in
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
                if !display.isProductionLot {
                    PrimaryButton(
                        title: display.needsProductionLink ? "Associa a piatto" : "Modifica collegamenti",
                        icon: "link"
                    ) {
                        onAssociate()
                    }
                    .disabled(!display.isActionable && !record.isNonCompliant)
                }

                if record.productStatus != .rejected {
                    SecondaryButton(
                        title: hasExistingLabel ? "Vedi etichetta HACCP" : "Crea etichetta HACCP",
                        icon: "tag.fill",
                        action: onLabel
                    )
                }

                SecondaryButton(title: "Segna non conforme", icon: "exclamationmark.triangle.fill", action: onNonCompliant)
                    .disabled(record.productStatus == .rejected)

                if canEditRecords {
                    SecondaryButton(title: "Modifica dati", icon: "pencil") {
                        if masterUser != nil {
                            showMasterEditAuth = true
                        } else {
                            onEdit()
                        }
                    }
                }

                if canDeleteRecords {
                    SecondaryButton(
                        title: display.isProductionLot
                            ? "Elimina produzione (errore — non resta salvata)"
                            : "Elimina alimento (errore — non resta salvato)",
                        icon: "trash"
                    ) {
                        showMasterDeleteAuth = true
                    }
                }

                if !display.isActionable {
                    Text("Lotto chiuso da Controllo scadenze: la chiusura resta documentata nei PDF.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func detailRow(_ title: String, _ value: String, highlight: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
            Spacer(minLength: 12)
            Text(value)
                .font(theme.typography.subheadline.weight(.semibold))
                .foregroundStyle(highlight ? theme.colorWarning : theme.colorTextPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func statusForAssociation(named productionName: String) -> TraceabilityLotOperationalStatus.Presentation? {
        if let production = associatedProductions.first(where: {
            $0.name.caseInsensitiveCompare(productionName) == .orderedSame
        }) {
            return productionStatusById[production.id]
        }
        return nil
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
        case .updated: return "pencil"
        }
    }

    private func timelineTitle(for log: TraceabilityLog) -> String {
        switch log.actionType {
        case .created: return "Creato"
        case .linkedToProduction:
            if let name = log.linkedProductionDisplayName(productionsById: productionsById) {
                return "Associato a \(name)"
            }
            return "Associato a produzione"
        case .expired: return "Segnato come scaduto (data)"
        case .rejected: return "Respinto"
        case .nonCompliance: return "Non conformità"
        case .withdrawn: return log.detail.map { "Chiusura: \($0)" } ?? "Chiusura (usato / scarto)"
        case .expiryRegistered: return log.detail ?? "Scadenza registrata"
        case .archivedFromExpiryControl: return log.detail.map { "Chiusura: \($0)" } ?? "Chiusura lotto"
        case .removedFromHistory: return "Nascosto dallo storico (resta in Documenti)"
        case .updated: return log.detail.map { "Modifica: \($0)" } ?? "Dati modificati"
        }
    }
}
