import SwiftUI
import SwiftData

/// Registrazione semplificata: fornitore + alimento in ingresso; tracciabilità lotto opzionale; foto in caso di anomalia.
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
    @State private var cameraSheet: IntakeCameraSheet?
    @StateObject private var anomalyCamera = FinalizeReceiptCameraViewModel()
    @StateObject private var labelCamera = FinalizeReceiptCameraViewModel()

    @State private var pendingCapture: PendingLottoCapture?
    @State private var manualLotCode = ""
    @State private var expiryDate = Date()
    @State private var expiryFromLabel = false
    @State private var expiryUserEdited = false
    @State private var showExpiredProductAlert = false
    @State private var acceptedDespiteExpired = false

    private let service = RicezioneMerceService()
    private let lottoService = LottoFotoService()

    private var lotTraceInput: RicezioneLotTraceInput? {
        guard !hasAnomaly else { return nil }
        var input = RicezioneLotTraceInput(
            pendingCapture: pendingCapture,
            manualLotCode: manualLotCode,
            expiryDate: resolvedExpiryDate,
            expiryFromLabel: expiryFromLabel,
            expiryUserEdited: expiryUserEdited,
            acceptedDespiteExpired: acceptedDespiteExpired
        )
        return input.hasLotOrExpiry ? input : nil
    }

    private var resolvedExpiryDate: Date? {
        if expiryUserEdited || expiryFromLabel || pendingCapture?.expiryFromLabel == true {
            return expiryDate
        }
        return pendingCapture?.labelExpiryDate
    }

    private var isExpiryReadAsExpired: Bool {
        guard let date = resolvedExpiryDate else { return false }
        return ProductExpiryEvaluator.isExpiredByDate(date)
            && (expiryFromLabel || pendingCapture?.expiryFromLabel == true)
            && !expiryUserEdited
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ricezione conforme") {
                    DatePicker("Data e ora", selection: $receivedAt)
                    LabeledContent("Fornitore", value: supplier.name)
                    LabeledContent("Alimento in ingresso", value: product.name)
                    LabeledContent("Categoria", value: product.category.rawValue)
                }

                if !hasAnomaly {
                    lotTraceSection
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
                        attemptSave()
                    }
                    .disabled(isSaving || pendingCapture?.isLotExtracting == true)
                }
            }
            .alert("Ricezione merci", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Prodotto scaduto", isPresented: $showExpiredProductAlert) {
                Button("Annulla", role: .cancel) {}
                Button("Accetta comunque", role: .destructive) {
                    acceptedDespiteExpired = true
                    Task { await save() }
                }
            } message: {
                Text("La scadenza letta è antecedente a oggi. Conferma solo se hai verificato e accetti la merce.")
            }
            .fullScreenCover(item: $cameraSheet) { sheet in
                receiptCameraSheet(for: sheet)
            }
        }
    }

    private enum IntakeCameraSheet: Identifiable {
        case anomaly
        case label

        var id: String {
            switch self {
            case .anomaly: return "anomaly"
            case .label: return "label"
            }
        }

        var title: String {
            switch self {
            case .anomaly: return "Foto anomalia"
            case .label: return "Foto etichetta"
            }
        }
    }

    @ViewBuilder
    private var lotTraceSection: some View {
        Section {
            if let pending = pendingCapture, let preview = HACCPZoomablePhotoThumbnail(data: pending.photoData, size: 72, zoomTitle: "Etichetta") {
                HStack {
                    preview
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Etichetta acquisita")
                            .font(theme.typography.caption.weight(.semibold))
                        if pending.isLotExtracting {
                            Text("Lettura AI in corso…")
                                .font(.caption2)
                                .foregroundStyle(theme.colorTextSecondary)
                        }
                    }
                    Spacer()
                    Button("Rifai") {
                        pendingCapture = nil
                        manualLotCode = ""
                        expiryFromLabel = false
                        expiryUserEdited = false
                    }
                    .font(.caption)
                }
            } else {
                Button {
                    cameraSheet = .label
                } label: {
                    Label("Scatta etichetta lotto", systemImage: "camera.viewfinder")
                }
            }

            TextField("Codice lotto (opzionale)", text: $manualLotCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onChange(of: manualLotCode) { _, newValue in
                    if var pending = pendingCapture {
                        pending.lotDraft = newValue
                        pendingCapture = pending
                    }
                }

            DatePicker("Scadenza (opzionale)", selection: $expiryDate, displayedComponents: .date)
                .onChange(of: expiryDate) { _, _ in
                    expiryUserEdited = true
                    expiryFromLabel = false
                }

            if isExpiryReadAsExpired {
                Label("Scadenza letta: prodotto scaduto", systemImage: "exclamationmark.octagon.fill")
                    .font(.caption)
                    .foregroundStyle(theme.colorError)
            } else if expiryFromLabel, let confidence = pendingCapture?.ocrConfidence,
                      confidence < GroqLotExtractor.manualVerificationThreshold {
                Label("Verifica lotto e scadenza letti dall'etichetta", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(theme.colorWarning)
            }
        } header: {
            Text("Tracciabilità lotto")
        } footer: {
            Text("Consigliato per collegare la ricezione a Controllo scadenze e Tracciabilità. Puoi anche inserire lotto e scadenza a mano.")
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
                    cameraSheet = .anomaly
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
                            cameraSheet = .anomaly
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

    @ViewBuilder
    private func receiptCameraSheet(for sheet: IntakeCameraSheet) -> some View {
        let camera = sheet == .anomaly ? anomalyCamera : labelCamera
        NavigationStack {
            VStack(spacing: 16) {
                FinalizeCameraSessionPreview(session: camera.session, cameraViewModel: camera)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Button("Scatta") { camera.capturePhoto() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle(sheet.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { cameraSheet = nil }
                }
            }
            .onAppear { camera.start() }
            .onDisappear { camera.stop() }
            .onReceive(camera.$capturedPhotoData) { data in
                guard let data, !data.isEmpty else { return }
                camera.resetCaptureBuffer()
                cameraSheet = nil
                switch sheet {
                case .anomaly:
                    anomalyPhotos.append(data)
                case .label:
                    beginLabelExtraction(from: data)
                }
            }
        }
    }

    private func beginLabelExtraction(from photoData: Data) {
        var pending = lottoService.makePendingCapture(photoData: photoData)
        pendingCapture = pending
        manualLotCode = pending.lotDraft
        Task {
            do {
                let outcome = try await lottoService.extractLot(from: photoData)
                pending.lotDraft = outcome.lotCode ?? pending.lotDraft
                pending.testoLottoOCR = outcome.lotCode
                pending.ocrRawText = outcome.rawText.nilIfEmpty
                pending.ocrConfidence = outcome.confidence
                pending.labelExpiryDate = outcome.expiryDate
                pending.expiryFromLabel = outcome.isExpiryFromLabel
                pending.isLotExtracting = false
                await MainActor.run {
                    pendingCapture = pending
                    manualLotCode = pending.lotDraft
                    if let labelExpiry = outcome.expiryDate {
                        expiryDate = labelExpiry
                        expiryFromLabel = outcome.isExpiryFromLabel
                        expiryUserEdited = false
                    }
                }
            } catch {
                await MainActor.run {
                    pending.isLotExtracting = false
                    pending.lotExtractionError = error.localizedDescription
                    pendingCapture = pending
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func attemptSave() {
        if isExpiryReadAsExpired, !acceptedDespiteExpired {
            showExpiredProductAlert = true
            return
        }
        Task { await save() }
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
                lotTrace: lotTraceInput,
                acceptedDespiteExpired: acceptedDespiteExpired,
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

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
