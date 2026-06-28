import AVFoundation
import Combine
import SwiftUI
import UIKit

@MainActor
final class FinalizeReceiptCameraViewModel: ObservableObject {
    let session = AVCaptureSession()
    @Published var authorizationDenied = false
    @Published private(set) var isSessionReady = false
    @Published private(set) var cameraUnavailable = false
    @Published var capturedPhotoData: Data?
    @Published var zoomFactor: CGFloat = 1.0

    private(set) var captureDevice: AVCaptureDevice?
    private var configured = false
    private let photoOutput = AVCapturePhotoOutput()
    private var photoDelegate: FinalizeReceiptPhotoCaptureDelegate?
    private var rotationCoordinator: AnyObject?
    weak var previewLayer: AVCaptureVideoPreviewLayer?
    private var wantsSessionRunning = false

    var maxZoomFactor: CGFloat {
        min(captureDevice?.activeFormat.videoMaxZoomFactor ?? 5.0, 5.0)
    }

    func setZoomFactor(_ factor: CGFloat) {
        guard let device = captureDevice else { return }
        let clamped = min(max(factor, 1.0), maxZoomFactor)
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
            zoomFactor = clamped
        } catch {
            zoomFactor = device.videoZoomFactor
        }
    }

    func cycleZoom() {
        let presets: [CGFloat] = [1.0, 2.0, 3.0].filter { $0 <= maxZoomFactor }
        guard !presets.isEmpty else { return }
        if let index = presets.firstIndex(where: { abs($0 - zoomFactor) < 0.05 }) {
            let next = presets[(index + 1) % presets.count]
            setZoomFactor(next)
        } else {
            setZoomFactor(presets[0])
        }
    }

    func registerPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer
        rotationCoordinator = nil
    }

    func resetCaptureBuffer() {
        capturedPhotoData = nil
    }

    private let sessionQueue = DispatchQueue(label: "haccp.camera.session", qos: .userInitiated)

    func start() {
        wantsSessionRunning = true
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor in
                guard let self, self.wantsSessionRunning else { return }
                self.authorizationDenied = !granted
                self.cameraUnavailable = false
                guard granted else {
                    self.isSessionReady = false
                    return
                }
                self.sessionQueue.async { [weak self] in
                    self?.startSessionOnQueue()
                }
            }
        }
    }

    func stop() {
        wantsSessionRunning = false
        let session = self.session
        sessionQueue.async { [weak self] in
            if session.isRunning {
                session.stopRunning()
            }
            Task { @MainActor in
                self?.isSessionReady = false
            }
        }
    }

    private func startSessionOnQueue() {
        guard wantsSessionRunning else { return }
        guard configureIfNeeded() else {
            Task { @MainActor in
                cameraUnavailable = true
                isSessionReady = false
            }
            return
        }
        let session = self.session
        if !session.isRunning {
            session.startRunning()
        }
        Task { @MainActor in
            isSessionReady = session.isRunning
            cameraUnavailable = !session.isRunning
        }
    }

    /// Allinea preview e scatto (WYSIWYG) tramite RotationCoordinator iOS 17+.
    func syncPreviewOrientation(previewLayer: AVCaptureVideoPreviewLayer) {
        previewLayer.frame = previewLayer.bounds
        guard let captureDevice else { return }

        if #available(iOS 17.0, *) {
            if rotationCoordinator == nil {
                rotationCoordinator = AVCaptureDevice.RotationCoordinator(
                    device: captureDevice,
                    previewLayer: previewLayer
                )
            }
            guard let coordinator = rotationCoordinator as? AVCaptureDevice.RotationCoordinator,
                  let connection = previewLayer.connection else { return }
            let angle = coordinator.videoRotationAngleForHorizonLevelPreview
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        } else if let connection = previewLayer.connection {
            CameraOrientationHelper.applyVideoRotation(to: connection)
        }
    }

    func capturePhoto() {
        guard session.isRunning else { return }
        let settings = AVCapturePhotoSettings()
        if let connection = photoOutput.connection(with: .video) {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
            if #available(iOS 17.0, *),
               let coordinator = rotationCoordinator as? AVCaptureDevice.RotationCoordinator {
                let angle = coordinator.videoRotationAngleForHorizonLevelCapture
                if connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
            } else {
                CameraOrientationHelper.applyVideoRotation(to: connection)
            }
        }
        let delegate = FinalizeReceiptPhotoCaptureDelegate(
            previewLayer: previewLayer
        ) { [weak self] data in
            DispatchQueue.main.async { self?.capturedPhotoData = data }
        }
        photoDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    @discardableResult
    private func configureIfNeeded() -> Bool {
        guard !configured else { return captureDevice != nil }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            return false
        }
        captureDevice = device
        session.addInput(input)
        configureAutofocus(on: device)
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
        }
        configured = true
        return true
    }

    private func configureAutofocus(on device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .none
            }
            device.unlockForConfiguration()
        } catch {
            // Autofocus best-effort: la sessione resta utilizzabile.
        }
    }
}

final class FinalizeReceiptPhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private let completion: (Data?) -> Void

    init(previewLayer: AVCaptureVideoPreviewLayer?, completion: @escaping (Data?) -> Void) {
        self.previewLayer = previewLayer
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil else {
            completion(nil)
            return
        }
        if var image = CameraCaptureImageProcessor.uprightUIImage(from: photo) {
            if let previewLayer {
                image = CameraCaptureImageProcessor.croppedToPreviewBounds(
                    image: image,
                    previewLayer: previewLayer
                )
            }
            completion(image.jpegData(compressionQuality: 0.92))
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion(nil)
            return
        }
        completion(CameraCaptureImageProcessor.uprightJPEGData(from: image))
    }
}

struct FinalizeCameraSessionPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var cameraViewModel: FinalizeReceiptCameraViewModel?
    var isSessionReady: Bool = false

    func makeUIView(context: Context) -> FinalizePreviewView {
        let view = FinalizePreviewView()
        view.cameraViewModel = cameraViewModel
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.connection?.automaticallyAdjustsVideoMirroring = false
        view.videoPreviewLayer.connection?.isVideoMirrored = false
        return view
    }

    func updateUIView(_ uiView: FinalizePreviewView, context: Context) {
        uiView.cameraViewModel = cameraViewModel
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
        if isSessionReady {
            uiView.setNeedsLayout()
        }
    }
}

final class FinalizePreviewView: UIView {
    weak var cameraViewModel: FinalizeReceiptCameraViewModel?
    private var orientationObserver: NSObjectProtocol?

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let preview = layer as? AVCaptureVideoPreviewLayer else {
            assertionFailure("FinalizePreviewView expects AVCaptureVideoPreviewLayer")
            return AVCaptureVideoPreviewLayer()
        }
        return preview
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            orientationObserver = NotificationCenter.default.addObserver(
                forName: UIDevice.orientationDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.setNeedsLayout()
            }
        } else if let orientationObserver {
            NotificationCenter.default.removeObserver(orientationObserver)
            self.orientationObserver = nil
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
        cameraViewModel?.registerPreviewLayer(videoPreviewLayer)
        Task { @MainActor in
            if let cameraViewModel {
                cameraViewModel.syncPreviewOrientation(previewLayer: videoPreviewLayer)
            } else if let connection = videoPreviewLayer.connection {
                CameraOrientationHelper.applyVideoRotation(to: connection)
            }
        }
    }
}

/// Camera pulita — preview, zoom digitale e scatto.
struct FullScreenLotCameraView: View {
    @ObservedObject var camera: FinalizeReceiptCameraViewModel
    let isProcessing: Bool
    var sessionPhotoCount: Int = 0
    let onCapture: () -> Void

    @Environment(\.theme) private var theme
    @State private var pinchBaseZoom: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if camera.authorizationDenied {
                    cameraPermissionDeniedView
                } else if camera.cameraUnavailable {
                    cameraUnavailableView
                } else {
                    FinalizeCameraSessionPreview(
                        session: camera.session,
                        cameraViewModel: camera,
                        isSessionReady: camera.isSessionReady
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .simultaneousGesture(zoomMagnificationGesture)
                }

                VStack {
                    HStack {
                        if sessionPhotoCount > 0 {
                            Text("\(sessionPhotoCount) foto")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.55))
                                .clipShape(Capsule())
                        }
                        Spacer()
                        if camera.maxZoomFactor > 1.1 {
                            Button {
                                camera.cycleZoom()
                                pinchBaseZoom = camera.zoomFactor
                            } label: {
                                Text(String(format: "%.1fx", camera.zoomFactor))
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.black.opacity(0.55))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Zoom digitale")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    Spacer()

                    if isProcessing {
                        ProgressView("Lettura lotto…")
                            .tint(.white)
                            .foregroundStyle(.white)
                            .padding(.bottom, 36)
                    } else {
                        Button(action: onCapture) {
                            ZStack {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 4)
                                    .frame(width: 72, height: 72)
                                Circle()
                                    .fill(.white)
                                    .frame(width: 58, height: 58)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 24)
                        .disabled(!camera.isSessionReady)
                        .opacity(camera.isSessionReady ? 1 : 0.45)
                        .accessibilityLabel("Scatta etichetta")
                    }
                }
            }
        }
        .onAppear {
            pinchBaseZoom = camera.zoomFactor
        }
        .onChange(of: camera.zoomFactor) { _, newValue in
            pinchBaseZoom = newValue
        }
    }

    private var zoomMagnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let target = pinchBaseZoom * value
                camera.setZoomFactor(target)
            }
            .onEnded { _ in
                pinchBaseZoom = camera.zoomFactor
            }
    }

    private var cameraUnavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.metering.unknown")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.8))
            Text("Fotocamera non disponibile")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Usa un iPad fisico con fotocamera posteriore. Sul simulatore la preview non è supportata.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private var cameraPermissionDeniedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.8))
            Text("Accesso fotocamera negato")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Abilita la fotocamera in Impostazioni per scattare le etichette.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}
