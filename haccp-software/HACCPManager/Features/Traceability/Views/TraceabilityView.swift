import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation
import Combine

struct TraceabilityView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var records: [TraceabilityRecord]
    @StateObject private var vm = TraceabilityViewModel()
    @StateObject private var camera = TraceabilityCameraViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?

    private var scopedRecords: [TraceabilityRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return records.filter { $0.restaurantId == rid }.sorted(by: { $0.createdAt > $1.createdAt })
    }
    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                captureWorkspace

                DashboardCardView(title: "Storico tracciabilita") {
                    if scopedRecords.isEmpty {
                        DashboardEmptyStateView(state: .init(
                            title: "Nessuna registrazione disponibile",
                            message: "Registra prodotti e lotti ricevuti per attivare la tracciabilita.",
                            actionTitle: nil
                        ))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(scopedRecords.prefix(30)) { record in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(record.productName).foregroundColor(.white)
                                        Text("Lotto: \(record.lotCode.isEmpty ? "-" : record.lotCode) · Fornitore: \(record.supplier.isEmpty ? "-" : record.supplier)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(10)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Tracciabilita")
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        vm.photoData = data
                    }
                }
            }
        }
        .alert("Tracciabilita", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .onAppear {
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
        .onReceive(camera.$capturedPhotoData) { data in
            guard let data else { return }
            vm.photoData = data
            if vm.selectedTab == .photo {
                vm.selectedTab = .date
            }
        }
    }

    private var captureWorkspace: some View {
        DashboardCardView(title: "Nuova registrazione") {
            GeometryReader { geo in
                HStack(spacing: 12) {
                    cameraPanel(width: geo.size.width * 0.55)
                    formPanel(width: geo.size.width * 0.45)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(height: 520)
        }
    }

    private func cameraPanel(width: CGFloat) -> some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black)
                    .overlay(
                        Group {
                            if camera.authorizationDenied {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 26))
                                        .foregroundColor(.gray)
                                    Text("Accesso fotocamera negato")
                                        .foregroundColor(.gray)
                                    Text("Abilita la fotocamera nelle impostazioni")
                                        .font(.caption)
                                        .foregroundColor(.gray.opacity(0.8))
                                }
                            } else {
                                CameraSessionPreview(session: camera.session)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if let data = vm.photoData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 130, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.5), lineWidth: 1))
                                .padding(10)
                        } else {
                            Text("Nessuna foto acquisita")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .padding(10)
                                .background(Color.black.opacity(0.45))
                                .cornerRadius(8)
                                .padding(10)
                        }
                    }
                    .overlay {
                        if camera.isRunning == false && camera.authorizationDenied == false {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.1)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(8)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                VStack {
                    HStack {
                        Spacer()
                        controlCircle(systemName: "scope")
                        controlCircle(systemName: "bolt.slash")
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            controlCircle(systemName: "photo")
                        }
                        controlCircle(systemName: "magnifyingglass")
                    }
                    .padding(12)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Button {
                    camera.capturePhoto()
                } label: {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 52, height: 52)
                        .overlay(Circle().stroke(Color.gray.opacity(0.5), lineWidth: 2))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 8)
        }
        .frame(width: width)
    }

    private func formPanel(width: CGFloat) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(TraceabilityViewModel.Tab.allCases) { tab in
                    Button {
                        guard vm.photoData != nil || tab == .photo else { return }
                        vm.selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.caption.bold())
                            .foregroundColor(tabIsEnabled(tab) ? (vm.selectedTab == tab ? .red : .gray) : .gray.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .disabled(!tabIsEnabled(tab))
                    .background(
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(vm.selectedTab == tab ? Color.red : Color.clear)
                                .frame(height: 2)
                        }
                    )
                }
            }
            .background(Color.white.opacity(0.03))
            .cornerRadius(10)

            if vm.photoData == nil {
                Text("Prima scatta una foto, poi compila data, lotto e appunti.")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            tabContent
                .frame(maxHeight: .infinity, alignment: .top)

            HStack(spacing: 10) {
                Button("Associare ad una produzione") {}
                    .buttonStyle(.bordered)
                    .tint(.white)
                Button("Ho finito") {
                    saveRecord()
                }
                .buttonStyle(.borderedProminent)
                .tint(vm.canSave ? .green : .gray)
                .disabled(!vm.canSave)
            }
        }
        .frame(width: width)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch vm.selectedTab {
        case .photo:
            VStack(alignment: .leading, spacing: 10) {
                TextField("Prodotto", text: $vm.productName)
                    .textFieldStyle(.roundedBorder)
                TextField("Fornitore", text: $vm.supplier)
                    .textFieldStyle(.roundedBorder)
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(vm.photoData == nil ? "Scatta una foto" : "Sostituisci foto", systemImage: "camera")
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }
        case .date:
            VStack(alignment: .leading, spacing: 10) {
                Text("Modificare la data").font(.headline).foregroundColor(.white)
                DatePicker("Data", selection: $vm.receivedAt, displayedComponents: .date)
                DatePicker("Ora", selection: $vm.receivedAt, displayedComponents: .hourAndMinute)
            }
            .foregroundColor(.white)
        case .lot:
            VStack(alignment: .leading, spacing: 10) {
                TextField("N lotto", text: $vm.lotCode)
                    .textFieldStyle(.roundedBorder)
                Toggle("Scadenza", isOn: $vm.includeExpiryDate)
                    .tint(.red)
                    .foregroundColor(.white)
                if vm.includeExpiryDate {
                    DatePicker("Data scadenza", selection: $vm.expiryDate, displayedComponents: .date)
                        .foregroundColor(.white)
                }
                TextField("Riferimento produzione", text: $vm.productionReference)
                    .textFieldStyle(.roundedBorder)
            }
        case .notes:
            VStack(alignment: .leading, spacing: 10) {
                Text("Inserire la nota").font(.headline).foregroundColor(.white)
                TextEditor(text: $vm.notes)
                    .frame(height: 140)
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
                    .foregroundColor(.white)
            }
        }
    }

    private func controlCircle(systemName: String) -> some View {
        Circle()
            .fill(Color.white.opacity(0.9))
            .frame(width: 34, height: 34)
            .overlay(Image(systemName: systemName).foregroundColor(.black).font(.caption.bold()))
    }

    private func saveRecord() {
        guard let rid = appState.activeRestaurantId, let currentUser else { return }
        do {
            try vm.service.addRecord(
                restaurantId: rid,
                productName: vm.productName,
                lotCode: vm.lotCode,
                supplier: vm.supplier,
                receivedAt: vm.receivedAt,
                expiryDate: vm.includeExpiryDate ? vm.expiryDate : nil,
                productionReference: vm.productionReference,
                photoData: vm.photoData,
                user: currentUser,
                notes: vm.notes,
                modelContext: modelContext
            )
            vm.resetForNext()
            selectedPhotoItem = nil
        } catch {
            vm.errorMessage = "Salvataggio tracciabilita non riuscito."
        }
    }

    private func tabIsEnabled(_ tab: TraceabilityViewModel.Tab) -> Bool {
        tab == .photo || vm.photoData != nil
    }
}

@MainActor
final class TraceabilityCameraViewModel: ObservableObject {
    let session = AVCaptureSession()
    @Published var authorizationDenied = false
    @Published var isRunning = false
    @Published var capturedPhotoData: Data?

    private var configured = false
    private let photoOutput = AVCapturePhotoOutput()
    private var photoDelegate: TraceabilityPhotoCaptureDelegate?

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.authorizationDenied = !granted
                guard granted else { return }
                self.configureIfNeeded()
                DispatchQueue.global(qos: .userInitiated).async {
                    if self.session.isRunning == false {
                        self.session.startRunning()
                    }
                    DispatchQueue.main.async {
                        self.isRunning = self.session.isRunning
                    }
                }
            }
        }
    }

    func stop() {
        DispatchQueue.global(qos: .userInitiated).async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        session.beginConfiguration()
        session.sessionPreset = .high
        defer {
            session.commitConfiguration()
            configured = true
        }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
    }

    func capturePhoto() {
        guard isRunning else { return }
        let settings = AVCapturePhotoSettings()
        if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
            settings.flashMode = .off
        }
        let delegate = TraceabilityPhotoCaptureDelegate { [weak self] data in
            DispatchQueue.main.async {
                self?.capturedPhotoData = data
            }
        }
        photoDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }
}

final class TraceabilityPhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Data?) -> Void

    init(completion: @escaping (Data?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            completion(nil)
            return
        }
        completion(photo.fileDataRepresentation())
    }
}

struct CameraSessionPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
