import SwiftUI

/// Dettaglio etichetta letta da QR — funziona su qualsiasi dispositivo, con tutti i campi HACCP.
struct ProductionLabelScannedDetailView: View {
    let data: ProductionLabelScanData
    var showsOfflineBanner: Bool = true
    var onOpenInArchive: (() -> Void)?

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacing.sectionSpacing) {
                    if showsOfflineBanner {
                        DashboardCardView(title: "Lettura QR", subtitle: "Da qualsiasi dispositivo") {
                            Text("Tutte le informazioni utili sono nel codice QR. Non serve che l’etichetta sia nell’archivio di questo dispositivo.")
                                .font(theme.typography.subheadline)
                                .foregroundStyle(theme.colorTextSecondary)
                        }
                    }

                    ProductionLabelStickerView(label: scannedPreviewRecord(from: data), compact: false)

                    statusBadges

                    DashboardCardView(title: "Informazioni etichetta", subtitle: "Dati HACCP completi") {
                        VStack(alignment: .leading, spacing: 10) {
                            if let restaurant = data.restaurantName, !restaurant.isEmpty {
                                infoRow("Ristorante", restaurant, icon: "building.2.fill")
                            }
                            if !data.productName.isEmpty {
                                infoRow("Prodotto", data.productName, icon: "tag.fill")
                            }
                            if let category = data.category, !category.isEmpty {
                                infoRow("Categoria", category, icon: "square.grid.2x2")
                            }
                            if let lot = data.lotCode, !lot.isEmpty {
                                infoRow("Lotto", lot, icon: "barcode")
                            }
                            if let production = data.productionDate {
                                infoRow(
                                    "Data produzione",
                                    production.formatted(date: .abbreviated, time: .shortened),
                                    icon: "calendar"
                                )
                            }
                            if let expiry = data.expiryDate {
                                infoRow(
                                    "Data scadenza",
                                    expiry.formatted(date: .abbreviated, time: .shortened),
                                    icon: "clock.badge.exclamationmark"
                                )
                            }
                            if let supplier = data.supplier, !supplier.isEmpty {
                                infoRow("Fornitore", supplier, icon: "shippingbox.fill")
                            }
                            if let qty = data.quantityDisplay, !qty.isEmpty {
                                infoRow("Quantità", qty, icon: "scalemass")
                            }
                            if let temp = data.temperatureNote, !temp.isEmpty {
                                infoRow("Temperatura", temp, icon: "thermometer.medium")
                            }
                            if let storage = data.storageInstructions, !storage.isEmpty {
                                infoRow("Conservazione", storage, icon: "snowflake")
                            }
                            if let op = data.operatorName, !op.isEmpty {
                                infoRow("Operatore", op, icon: "person.fill")
                            }
                            if let status = data.productStatusLabel, !status.isEmpty {
                                infoRow("Stato prodotto", status, icon: "checkmark.seal")
                            }
                            if let source = data.sourceModuleLabel, !source.isEmpty {
                                infoRow("Origine HACCP", source, icon: "link")
                            }
                            if let notes = data.notes, !notes.isEmpty {
                                infoRow("Note", notes, icon: "note.text")
                            }
                            infoRow("ID tracciabilità", data.id.uuidString.uppercased(), icon: "qrcode")
                        }
                    }

                    if !data.allergenList.isEmpty {
                        DashboardCardView(title: "Allergeni") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(data.allergenList, id: \.self) { allergen in
                                    HACCPBadge(title: allergen, style: .warning, showIcon: false)
                                }
                            }
                        }
                    }

                    if let onOpenInArchive {
                        PrimaryButton(title: "Apri etichetta in archivio", icon: "archivebox") {
                            onOpenInArchive()
                        }
                    }
                }
                .padding(theme.spacing.screenPadding + 8)
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle(data.productName.isEmpty ? "Etichetta scansionata" : data.productName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var statusBadges: some View {
        HStack(spacing: 8) {
            switch data.expiryState {
            case .ok:
                HACCPBadge(title: data.expiryState.badgeTitle, style: .conforme, showIcon: true)
            case .soon:
                HACCPBadge(title: data.expiryState.badgeTitle, style: .warning, showIcon: true)
            case .expired:
                HACCPBadge(title: data.expiryState.badgeTitle, style: .nonConforme, showIcon: true)
            }
            if let status = data.productStatusLabel, !status.isEmpty {
                HACCPBadge(title: status, style: .info, showIcon: false)
            }
            if !data.allergenList.isEmpty {
                HACCPBadge(title: "Allergeni", style: .warning, showIcon: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func infoRow(_ title: String, _ value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.colorTextSecondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                Text(value)
                    .font(theme.typography.subheadline)
                    .foregroundStyle(theme.colorTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func scannedPreviewRecord(from data: ProductionLabelScanData) -> ProductionLabelRecord {
        let record = ProductionLabelRecord(
            id: data.id,
            restaurantId: UUID(),
            productName: data.productName.isEmpty ? "Etichetta HACCP" : data.productName,
            productionDate: data.productionDate ?? Date(),
            expiryDate: data.expiryDate ?? Date(),
            lotCode: data.lotCode,
            createdByUserId: UUID(),
            createdByNameSnapshot: data.operatorName ?? "—",
            notes: data.notes,
            category: data.category,
            supplier: data.supplier,
            allergens: data.allergens,
            storageInstructions: data.storageInstructions,
            temperatureNote: data.temperatureNote
        )
        applyQuantityDisplay(data.quantityDisplay, to: record)
        record.qrPayload = ProductionLabelQRService.buildPayload(
            for: record,
            restaurantName: data.restaurantName
        )
        return record
    }

    private func applyQuantityDisplay(_ display: String?, to record: ProductionLabelRecord) {
        guard let display, !display.isEmpty else { return }
        let parts = display.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let first = parts.first, let value = Double(first.replacingOccurrences(of: ",", with: ".")) else { return }
        record.quantity = value
        if parts.count > 1 {
            record.unit = String(parts[1])
        }
    }
}
