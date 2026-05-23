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

    private let service = ProductionLabelsService()

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.sectionSpacing) {
                ProductionLabelStickerView(label: label)

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
                    PrimaryButton(title: "Esporta PDF", icon: "doc.fill") { exportPDF() }
                    SecondaryButton(title: "Duplica etichetta", icon: "doc.on.doc") { duplicate() }
                    SecondaryButton(title: "Prepara ristampa", icon: "printer") { prepareReprint() }
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

    private func prepareReprint() {
        do {
            try service.markReprinted(label, modelContext: modelContext)
            onChanged()
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
