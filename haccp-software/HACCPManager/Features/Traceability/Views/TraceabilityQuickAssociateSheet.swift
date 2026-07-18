import SwiftUI
import SwiftData

/// Associazione rapida a un singolo piatto, con foto opzionale del piatto finito.
struct TraceabilityQuickAssociateSheet: View {
    let record: TraceabilityRecord
    let productions: [Production]
    let categories: [ProductionCategory]
    let onConfirm: (Production, Data?) -> Void
    let onCancel: () -> Void

    @Environment(\.theme) private var theme
    @State private var selectedCategoryId: UUID?
    @State private var selectedProduction: Production?
    @State private var productionPhotoData: Data?
    @State private var showCamera = false
    @StateObject private var camera = FinalizeReceiptCameraViewModel()

    private var filteredProductions: [Production] {
        guard let selectedCategoryId else { return productions }
        return productions.filter { $0.categoryId == selectedCategoryId }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.productName)
                            .font(theme.typography.headline)
                        if !record.lotCode.isEmpty {
                            Text("Lotto fornitore \(record.lotCode)")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary)
                        }
                    }

                    Text("Scegli il piatto e, se vuoi, scatta una foto del piatto finito (non dell’alimento in ingresso).")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)

                    productionPhotoSection

                    categoryTabs

                    if filteredProductions.isEmpty {
                        Text("Nessun piatto in questa categoria.")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                    } else {
                        BlastChillingProductionGridView(
                            productions: filteredProductions,
                            selectedProductionId: selectedProduction?.id,
                            showsShelfLife: true,
                            onSelect: { selectedProduction = $0 }
                        )
                    }
                }
                .padding()
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle("Associa piatto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Conferma") {
                        if let production = selectedProduction {
                            onConfirm(production, productionPhotoData)
                        }
                    }
                    .disabled(selectedProduction == nil)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                productionCameraSheet
            }
        }
    }

    private var productionPhotoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Foto piatto finito")
                .font(theme.typography.subheadline.weight(.semibold))
            if let productionPhotoData,
               let thumb = HACCPZoomablePhotoThumbnail(
                data: productionPhotoData,
                size: 96,
                zoomTitle: "Piatto finito"
               ) {
                HStack(spacing: 12) {
                    thumb
                    VStack(alignment: .leading, spacing: 8) {
                        Button("Scatta di nuovo") { showCamera = true }
                            .font(theme.typography.caption.weight(.semibold))
                        Button("Rimuovi") { self.productionPhotoData = nil }
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorError)
                    }
                }
            } else {
                Button {
                    showCamera = true
                } label: {
                    Label("Scatta foto del piatto", systemImage: "camera.fill")
                        .font(theme.typography.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var productionCameraSheet: some View {
        NavigationStack {
            ZStack {
                FinalizeCameraSessionPreview(session: camera.session, cameraViewModel: camera)
                    .ignoresSafeArea()
                VStack {
                    Spacer()
                    Button("Scatta") { camera.capturePhoto() }
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom, 28)
                }
            }
            .navigationTitle("Foto piatto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { showCamera = false }
                }
            }
            .onAppear { camera.start() }
            .onDisappear { camera.stop() }
            .onReceive(camera.$capturedPhotoData) { data in
                guard let data, !data.isEmpty else { return }
                camera.resetCaptureBuffer()
                showCamera = false
                productionPhotoData = data
            }
        }
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryButton(nil, title: "Tutte")
                ForEach(categories) { category in
                    categoryButton(category.id, title: category.name)
                }
            }
        }
    }

    private func categoryButton(_ id: UUID?, title: String) -> some View {
        Button {
            selectedCategoryId = id
        } label: {
            Text(title)
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(selectedCategoryId == id ? theme.colorTextOnPrimary : theme.colorTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedCategoryId == id ? theme.colorPrimary : theme.colorDivider)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
