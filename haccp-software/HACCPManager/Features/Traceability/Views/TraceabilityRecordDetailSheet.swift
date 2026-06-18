//
//  TraceabilityRecordDetailSheet.swift
//

import SwiftUI

struct TraceabilityRecordDetailSheet: View {
    let record: TraceabilityRecord
    let display: TraceabilityRecordDisplay
    let image: UIImage?
    let associatedProductions: [Production]
    let defrostRecords: [DefrostRecord]
    let receiptStatus: String?
    let canDeleteRecords: Bool
    let onAssociate: () -> Void
    let onLabel: () -> Void
    let onNonCompliant: () -> Void
    let onWithdraw: () -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.sectionSpacing) {
                    headerBlock
                    infoCard
                    if !associatedProductions.isEmpty {
                        productionsCard
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
        }
    }

    private var headerBlock: some View {
        HStack(alignment: .top, spacing: 16) {
            if let image {
                HACCPZoomablePhotoThumbnail(image: image, size: 96, zoomTitle: display.productName)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 8) {
                HACCPBadge(title: display.statusLabel, style: display.badgeStyle)
                Text("Ricevuto \(display.receivedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                if let receiptStatus {
                    Text("Stato ricezione: \(receiptStatus)")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorWarning)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var infoCard: some View {
        DashboardCardView(title: "Scheda prodotto", subtitle: "Dati HACCP") {
            VStack(spacing: 10) {
                detailRow("Lotto", display.lot)
                detailRow("Fornitore", display.supplier)
                if let category = display.category {
                    detailRow("Categoria", category)
                }
                if let expiry = display.expiryDate {
                    detailRow(
                        "Scadenza",
                        expiry.formatted(date: .abbreviated, time: .omitted),
                        highlight: display.expiryWarning
                    )
                }
            }
        }
    }

    private var productionsCard: some View {
        DashboardCardView(title: "Produzioni associate", subtitle: "\(associatedProductions.count) collegate") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(associatedProductions) { production in
                    HStack(spacing: 8) {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(theme.colorSuccess)
                        Text(production.name)
                            .font(theme.typography.subheadline)
                            .foregroundStyle(theme.colorTextPrimary)
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
                PrimaryButton(title: "Associa a produzione", icon: "link") {
                    onDismiss()
                    onAssociate()
                }
                .disabled(!display.isActionable)

                if record.canBeWithdrawn {
                    PrimaryButton(title: "Segna ritirato / scartato", icon: "archivebox.fill") {
                        onDismiss()
                        onWithdraw()
                    }
                }

                if record.productStatus != .rejected {
                    SecondaryButton(title: "Crea etichetta HACCP", icon: "tag.fill") {
                        onDismiss()
                        onLabel()
                    }
                }

                SecondaryButton(title: "Segna non conforme", icon: "exclamationmark.triangle.fill") {
                    onDismiss()
                    onNonCompliant()
                }
                .disabled(record.productStatus == .rejected)

                if canDeleteRecords {
                    SecondaryButton(title: "Elimina scheda", icon: "trash") {
                        onDismiss()
                        onDelete()
                    }
                }

                if !display.isActionable && !record.canBeWithdrawn {
                    Text("Prodotto scaduto o respinto: non associabile a produzioni.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorWarning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if record.canBeWithdrawn {
                    Text("Lotto scaduto: registra ritiro o scarto per chiudere la criticità.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorWarning)
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
}
