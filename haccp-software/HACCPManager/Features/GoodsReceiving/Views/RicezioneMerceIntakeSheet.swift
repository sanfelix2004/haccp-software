import SwiftUI
import SwiftData

/// Registrazione semplificata: fornitore + alimento in ingresso; foto solo in caso di anomalia.
struct RicezioneMerceIntakeSheet: View {
    let restaurantId: UUID
    let supplier: Supplier
    let product: ProductTemplate
    let user: LocalUser
    let onSaved: () -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var receivedAt = Date()
    @State private var hasAnomaly = false
    @State private var anomalyDescription = ""
    @State private var anomalyAction: AzioneNonConformita?
    @State private var anomalyPhotos: [Data] = []
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var showAnomalyCamera = false
    @StateObject private var anomalyCamera = FinalizeReceiptCameraViewModel()

    private let service = RicezioneMerceService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Ricezione conforme") {
                    DatePicker("Data e ora", selection: $receivedAt)
                    LabeledContent("Fornitore", value: supplier.name)
                    LabeledContent("Alimento in ingresso", value: product.name)
                    LabeledContent("Categoria", value: product.category.rawValue)
                }

                Section {
                    Toggle("Problema con la merce", isOn: $hasAnomaly)
                        .tint(theme.colorWarning)
                } footer: {
                    Text("Lascia disattivato se la merce è conforme. Attiva solo per danni, confezioni rotte o altre anomalie: servono foto e indicazione se hai scartato o restituito al fornitore.")
                }

                if hasAnomaly {
                    anomalySection
                }
            }
            .navigationTitle("Conferma ricezione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Salvo…" : "Salva") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Ricezione merci", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .fullScreenCover(isPresented: $showAnomalyCamera) {
                anomalyCameraSheet
            }
        }
    }

    @ViewBuilder
    private var anomalySection: some View {
        Section("Non conformità") {
            TextField("Descrizione del problema", text: $anomalyDescription, axis: .vertical)
                .lineLimit(3...6)

            Picker("Cosa hai fatto", selection: $anomalyAction) {
                Text("Seleziona…").tag(AzioneNonConformita?.none)
                ForEach(AzioneNonConformita.allCases) { action in
                    Text(action.label).tag(Optional(action))
                }
            }

            if anomalyPhotos.isEmpty {
                Button {
                    showAnomalyCamera = true
                } label: {
                    Label("Scatta foto anomalia", systemImage: "camera.fill")
                }
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(Array(anomalyPhotos.enumerated()), id: \.offset) { _, data in
                            if let preview = HACCPZoomablePhotoThumbnail(data: data, size: 72, zoomTitle: "Foto anomalia") {
                                preview
                            }
                        }
                        Button {
                            showAnomalyCamera = true
                        } label: {
                            VStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Altra foto")
                                    .font(.caption2)
                            }
                            .frame(width: 72, height: 72)
                        }
                    }
                }
            }
        }
    }

    private var anomalyCameraSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                FinalizeCameraSessionPreview(session: anomalyCamera.session, cameraViewModel: anomalyCamera)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Button("Scatta") { anomalyCamera.capturePhoto() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Foto anomalia")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { showAnomalyCamera = false }
                }
            }
            .onAppear { anomalyCamera.start() }
            .onDisappear { anomalyCamera.stop() }
            .onReceive(anomalyCamera.$capturedPhotoData) { data in
                guard let data, !data.isEmpty else { return }
                anomalyCamera.resetCaptureBuffer()
                showAnomalyCamera = false
                anomalyPhotos.append(data)
            }
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try service.saveIntake(
                restaurantId: restaurantId,
                supplier: supplier,
                product: product,
                receivedAt: receivedAt,
                hasAnomaly: hasAnomaly,
                anomalyDescription: anomalyDescription,
                anomalyPhotos: anomalyPhotos,
                anomalyAction: anomalyAction,
                user: user,
                modelContext: modelContext
            )
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
