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
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var errorMessage: String?
    @State private var isPrinting = false

    @ObservedObject private var printerManager = ClabelPrinterManager.shared

    private let service = ProductionLabelsService()

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.sectionSpacing) {
                ProductionLabelStickerView(label: label)

                if SettingsStorageService.shared.printer.showQRCode {
                    DashboardCardView(title: "Codice QR", subtitle: "Leggibile da qualsiasi dispositivo") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Il QR contiene prodotto, lotto, date, allergeni e altre info HACCP. Puoi scansionarlo da un altro telefono anche senza archivio locale.")
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
                        linkRow("Origine", label.sourceModule.label, icon: label.sourceModule.icon)
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

                if !label.allergenList.isEmpty {
                    DashboardCardView(title: "Allergeni") {
                        FlowLayoutBadges(items: label.allergenList)
                    }
                }

                VStack(spacing: 12) {
                    PrimaryButton(title: isPrinting ? "Stampa…" : "Stampa etichetta", icon: "printer.fill") {
                        Task { await printLabel() }
                    }
                    .disabled(isPrinting || !printerManager.isReadyToPrint)

                    if printerManager.isConnected && !printerManager.isReadyToPrint {
                        Text("Stampante collegata ma canale stampa non pronto. Attendi o riconnetti da Impostazioni.")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorWarning)
                            .multilineTextAlignment(.center)
                    }
                    PrimaryButton(title: "Esporta PDF", icon: "doc.fill") { exportPDF() }
                    SecondaryButton(title: "Duplica etichetta", icon: "doc.on.doc") { duplicate() }
                    SecondaryButton(title: "Prepara ristampa", icon: "printer") {
                        Task { await reprintLabel() }
                    }
                    if !label.isArchived {
                        SecondaryButton(title: "Archivia", icon: "archivebox") { archive() }
                    }
                }
            }
            .padding(theme.spacing.screenPadding + 8)
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
                onSaved: {
                    showEdit = false
                    onChanged()
                },
                onCancel: { showEdit = false }
            )
        }
        .sheet(isPresented: $showShare, onDismiss: { shareURL = nil }) {
            if let shareURL {
                ProductionLabelShareSheet(url: shareURL)
            }
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

    private func exportPDF() {
        do {
            shareURL = try ProductionLabelPDFExporter.export(labels: [label], restaurantName: restaurantName)
            showShare = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func duplicate() {
        do {
            _ = try service.duplicate(label, user: user, modelContext: modelContext)
            onChanged()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func printLabel() async {
        guard printerManager.isReadyToPrint else {
            errorMessage = printerManager.isConnected
                ? "Canale stampa non pronto. Vai in Impostazioni → Stampanti e attendi «Connessa»."
                : "Collega la stampante da Impostazioni → Stampanti."
            return
        }
        isPrinting = true
        defer { isPrinting = false }
        do {
            try await ProductionLabelPrintQueue.shared.printNow(
                label: label,
                restaurantName: restaurantName
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            printerManager.lastErrorMessage = error.localizedDescription
        }
    }

    private func reprintLabel() async {
        do {
            try service.markReprinted(label, modelContext: modelContext)
            onChanged()
            await printLabel()
        } catch {
            errorMessage = error.localizedDescription
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

private struct ProductionLabelShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
