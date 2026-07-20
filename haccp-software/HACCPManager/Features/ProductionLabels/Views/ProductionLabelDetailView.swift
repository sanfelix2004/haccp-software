//
//  ProductionLabelDetailView.swift
//

import SwiftUI
import SwiftData

struct ProductionLabelDetailView: View {
    let label: ProductionLabelRecord
    let restaurantName: String
    let user: LocalUser
    let onChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var showEdit = false
    @State private var errorMessage: String?
    @State private var isPrinting = false
    @State private var photoData: Data?
    @State private var queuedPrintMessage: String?
    @State private var selectedTab: DetailTab = .sticker
    @State private var productionContext: ProductionLabelProductionContext?

    @ObservedObject private var printerManager = ClabelPrinterManager.shared
    @ObservedObject private var printQueue = ProductionLabelPrintQueue.shared

    private enum DetailTab: String, CaseIterable, Identifiable {
        case sticker = "Etichetta"
        case details = "Dettagli"

        var id: String { rawValue }
    }

    private let service = ProductionLabelsService()

    var body: some View {
        VStack(spacing: 0) {
            Picker("Scheda", selection: $selectedTab) {
                ForEach(DetailTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, theme.spacing.screenPadding + 8)
            .padding(.vertical, 12)

            ScrollView {
                VStack(spacing: theme.spacing.sectionSpacing) {
                    switch selectedTab {
                    case .sticker:
                        stickerTab
                    case .details:
                        detailsTab
                    }
                }
                .padding(theme.spacing.screenPadding + 8)
            }
        }
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle(label.productName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Modifica") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            ProductionLabelEditorSheet(
                mode: .edit(label),
                restaurantId: label.restaurantId,
                user: user,
                onSaved: { _, shouldPrint in
                    showEdit = false
                    onChanged()
                    guard shouldPrint else { return }
                    Task { await printLabel(countAsReprint: true) }
                },
                onCancel: { showEdit = false }
            )
        }
        .alert("Etichette", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Stampa", isPresented: Binding(
            get: { printerManager.lastSuccessMessage != nil },
            set: { if !$0 { printerManager.lastSuccessMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(printerManager.lastSuccessMessage ?? "")
        }
        .onChange(of: printerManager.lastErrorMessage) { _, msg in
            if let msg { errorMessage = msg }
        }
        .task(id: label.id) {
            photoData = ProductionLabelImageResolver.imageData(for: label, context: modelContext)
            productionContext = ProductionLabelProductionContextLoader.load(
                for: label,
                context: modelContext
            )
        }
    }

    @ViewBuilder
    private var stickerTab: some View {
        if let photoData,
           let preview = HACCPZoomablePhotoPreview(data: photoData, height: 220, zoomTitle: label.productName) {
            DashboardCardView(title: "Foto prodotto", subtitle: "Da tracciabilità o ricezione collegata") {
                preview
            }
        }

        ProductionLabelStickerView(label: label)

        VStack(spacing: 12) {
            PrimaryButton(title: isPrinting ? "Stampa…" : "Stampa etichetta", icon: "printer.fill") {
                Task { await printLabel() }
            }
            .disabled(isPrinting)

            if let queuedPrintMessage {
                Text(queuedPrintMessage)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorInfo)
                    .multilineTextAlignment(.center)
            } else if printerManager.isConnected && !printerManager.isReadyToPrint {
                Text("Stampante collegata: la stampa verrà accodata finché il canale non è pronto.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorWarning)
                    .multilineTextAlignment(.center)
            } else if !printerManager.isConnected {
                Text("Collega la stampante da Impostazioni → Stampanti.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorWarning)
                    .multilineTextAlignment(.center)
            }

            if !label.isArchived {
                SecondaryButton(title: "Archivia", icon: "archivebox") { archive() }
            }
        }
    }

    @ViewBuilder
    private var detailsTab: some View {
        if SettingsStorageService.shared.printer.showQRCode {
            DashboardCardView(title: "Codice QR", subtitle: "Scansione solo da iPad") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Il QR collega l’etichetta all’archivio HACCP. Scansionarlo solo dall’app su iPad.")
                        .font(theme.typography.subheadline)
                        .foregroundStyle(theme.colorTextSecondary)
                    Text("ID: \(label.id.uuidString.prefix(8).uppercased())…")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }
        }

        DashboardCardView(title: "Collegamenti HACCP") {
            VStack(alignment: .leading, spacing: 10) {
                linkRow("Origine", label.sourceModule.displayLabel, icon: label.sourceModule.icon)
                if label.traceabilityRecordId != nil {
                    linkRow("Tracciabilità", "Collegata", icon: "link")
                }
                if label.goodsReceiptId != nil {
                    linkRow("Ricezione merci", "Collegata", icon: "shippingbox.fill")
                }
                if label.blastChillingRecordId != nil {
                    linkRow("Abbattimento", "Collegata", icon: "wind.snow")
                }
                if label.defrostRecordId != nil {
                    linkRow("Decongelamento", "Collegata", icon: "snowflake")
                }
                linkRow("Ristampe", "\(label.reprintCount)", icon: "printer")
                linkRow("Creata", label.createdAt.formatted(date: .abbreviated, time: .shortened), icon: "clock")
                linkRow("Aggiornata", label.updatedAt.formatted(date: .abbreviated, time: .shortened), icon: "arrow.clockwise")
            }
        }

        if let productionContext {
            ProductionLabelProductionContextSection(context: productionContext)
        }

        if !label.allergenList.isEmpty {
            DashboardCardView(title: "Allergeni") {
                FlowLayoutBadges(items: label.allergenList)
            }
        }
    }

    private func linkRow(_ title: String, _ value: String, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(theme.typography.subheadline)
                .foregroundStyle(theme.colorTextSecondary)
            Spacer()
            Text(value)
                .font(theme.typography.subheadline)
                .foregroundStyle(theme.colorTextPrimary)
        }
    }

    private func printLabel(countAsReprint: Bool = true) async {
        isPrinting = true
        defer { isPrinting = false }
        queuedPrintMessage = nil

        if printerManager.isReadyToPrint {
            do {
                try await printQueue.printNow(
                    label: label,
                    restaurantName: restaurantName,
                    modelContext: modelContext,
                    countAsReprint: countAsReprint
                )
                errorMessage = nil
                onChanged()
            } catch {
                errorMessage = error.localizedDescription
                printerManager.lastErrorMessage = error.localizedDescription
            }
            return
        }

        guard printerManager.isConnected else {
            errorMessage = "Collega la stampante da Impostazioni → Stampanti."
            return
        }

        printQueue.enqueue(labelId: label.id, countAsReprint: countAsReprint)
        queuedPrintMessage = "Etichetta in coda. Stampa automatica appena la stampante è pronta."
        await printQueue.processPending(
            labels: [label],
            modelContext: modelContext,
            restaurantName: restaurantName
        )
        if printQueue.pendingJobs.contains(where: { $0.labelId == label.id }) == false {
            queuedPrintMessage = nil
            onChanged()
        }
    }

    private func archive() {
        do {
            try service.archive(label, modelContext: modelContext)
            onChanged()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct FlowLayoutBadges: View {
    let items: [String]

    var body: some View {
        FlexibleView(data: items, spacing: 8) { item in
            HACCPBadge(title: item, style: .warning, showIcon: false)
        }
    }
}

/// Layout semplice a capo per badge allergeni.
private struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(data), id: \.self) { item in
                content(item)
            }
        }
    }
}
