import SwiftUI
import Vision
import VisionKit

enum ProductionLabelScannerSupport {
    /// Scanner QR solo su iPad (non su iPhone).
    static var isAvailable: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
            && DataScannerViewController.isSupported
            && DataScannerViewController.isAvailable
    }

    static var unavailableMessage: String {
        if UIDevice.current.userInterfaceIdiom != .pad {
            return "La scansione QR etichette è disponibile solo su iPad."
        }
        return "Scanner non disponibile su questo dispositivo."
    }
}

struct ProductionLabelScannerSheet: View {
    let onScan: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var didScan = false
    @State private var scannerError: String?

    var body: some View {
        NavigationStack {
            Group {
                if ProductionLabelScannerSupport.isAvailable {
                    ProductionLabelQRScannerRepresentable { payload in
                        guard !didScan else { return }
                        didScan = true
                        onScan(payload)
                        dismiss()
                    }
                    .ignoresSafeArea()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "ipad")
                            .font(.largeTitle)
                            .foregroundStyle(theme.colorTextSecondary)
                        Text(ProductionLabelScannerSupport.unavailableMessage)
                            .font(theme.typography.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(theme.colorTextSecondary)
                    }
                    .padding(32)
                }
            }
            .navigationTitle("Scansiona etichetta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("Inquadra il QR dell’etichetta. La scansione funziona solo da iPad.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
            }
            .alert("Scanner", isPresented: Binding(
                get: { scannerError != nil },
                set: { if !$0 { scannerError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(scannerError ?? "")
            }
        }
    }
}

private struct ProductionLabelQRScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.scanner = scanner
        guard !context.coordinator.started else { return }
        context.coordinator.started = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            try? scanner.startScanning()
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
        coordinator.started = false
        coordinator.scanner = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        var started = false
        weak var scanner: DataScannerViewController?

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            process(items: addedItems)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didUpdate updatedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            process(items: updatedItems)
        }

        private func process(items: [RecognizedItem]) {
            for item in items {
                guard case .barcode(let barcode) = item else { continue }
                let payload = barcode.payloadStringValue
                guard let payload, !payload.isEmpty else { continue }
                guard ProductionLabelQRService.parseScanned(payload) != nil else { continue }
                scanner?.stopScanning()
                onScan(payload)
                return
            }
        }
    }
}
