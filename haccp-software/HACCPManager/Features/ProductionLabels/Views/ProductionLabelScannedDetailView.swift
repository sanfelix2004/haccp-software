import SwiftUI

/// Dettaglio etichetta letta da QR — disponibile anche senza archivio locale (altro dispositivo).
struct ProductionLabelScannedDetailView: View {
    let data: ProductionLabelScanData
    var showsOfflineBanner: Bool = true

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacing.sectionSpacing) {
                    if showsOfflineBanner {
                        DashboardCardView(title: "Lettura QR", subtitle: "Da qualsiasi dispositivo") {
                            Text("Tutte le informazioni sono nel codice QR. Non serve che l’etichetta sia nell’archivio di questo telefono.")
                                .font(theme.typography.subheadline)
                                .foregroundStyle(theme.colorTextSecondary)
                        }
                    }

                    ProductionLabelScannedStickerView(data: data)

                    DashboardCardView(title: "Dettagli HACCP") {
                        VStack(alignment: .leading, spacing: 10) {
                            if let restaurant = data.restaurantName, !restaurant.isEmpty {
                                infoRow("Ristorante", restaurant, icon: "building.2.fill")
                            }
                            infoRow("Prodotto", data.productName, icon: "tag.fill")
                            if let category = data.category, !category.isEmpty {
                                infoRow("Categoria", category, icon: "square.grid.2x2")
                            }
                            if let lot = data.lotCode, !lot.isEmpty {
                                infoRow("Lotto", lot, icon: "barcode")
                            }
                            if let production = data.productionDate {
                                infoRow(
                                    "Produzione",
                                    production.formatted(date: .abbreviated, time: .shortened),
                                    icon: "calendar"
                                )
                            }
                            if let expiry = data.expiryDate {
                                infoRow(
                                    "Scadenza",
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
                                infoRow("Stato", status, icon: "checkmark.seal")
                            }
                            if let source = data.sourceModuleLabel, !source.isEmpty {
                                infoRow("Origine", source, icon: "link")
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
                }
                .padding(theme.spacing.screenPadding + 8)
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle("Etichetta scansionata")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
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
            }
            Spacer(minLength: 0)
        }
    }
}

private struct ProductionLabelScannedStickerView: View {
    let data: ProductionLabelScanData

    @Environment(\.theme) private var theme
    @Bindable private var settingsStorage = SettingsStorageService.shared
    @State private var qrImage: UIImage?

    private var printerSettings: LabelPrinterSettings {
        settingsStorage.printer
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("HACCP")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colorPrimary)
                    .tracking(1.2)

                Text(data.productName)
                    .font(theme.typography.title3)
                    .foregroundStyle(theme.colorTextPrimary)
                    .lineLimit(2)

                if let lot = data.lotCode, !lot.isEmpty {
                    row(icon: "barcode", text: "Lotto \(lot)")
                }
                if let production = data.productionDate {
                    row(icon: "calendar", text: "Prod. \(production.formatted(date: .abbreviated, time: .omitted))")
                }
                if let expiry = data.expiryDate {
                    row(icon: "clock.badge.exclamationmark", text: "Scad. \(expiry.formatted(date: .abbreviated, time: .omitted))")
                }
                if let op = data.operatorName, !op.isEmpty {
                    row(icon: "person.fill", text: op)
                }

                HStack(spacing: 6) {
                    expiryBadge
                    if !data.allergenList.isEmpty {
                        HACCPBadge(title: "Allergeni", style: .warning, showIcon: true)
                    }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if printerSettings.showQRCode, let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .fill(theme.colorSurfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(theme.colorDivider)
        )
        .onAppear { loadQR() }
    }

    @ViewBuilder
    private var expiryBadge: some View {
        switch data.expiryState {
        case .ok:
            HACCPBadge(title: "OK", style: .conforme, showIcon: true)
        case .soon:
            HACCPBadge(title: "Presto", style: .warning, showIcon: true)
        case .expired:
            HACCPBadge(title: "Scaduto", style: .nonConforme, showIcon: true)
        }
    }

    private func row(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.colorTextSecondary)
                .frame(width: 14)
            Text(text)
                .font(theme.typography.subheadline)
                .foregroundStyle(theme.colorTextPrimary)
                .lineLimit(2)
        }
    }

    private func loadQR() {
        guard printerSettings.showQRCode else {
            qrImage = nil
            return
        }
        let payload = ProductionLabelQRService.buildPayload(
            for: previewRecord,
            restaurantName: data.restaurantName
        )
        qrImage = ProductionLabelQRService.image(from: payload, dimension: 160)
    }

    private var previewRecord: ProductionLabelRecord {
        ProductionLabelRecord(
            id: data.id,
            restaurantId: UUID(),
            productName: data.productName,
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
    }
}
