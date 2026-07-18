import SwiftUI
import SwiftData

/// Dettaglio batch produzione con multi-scatto OCR lotti ingredienti.
struct ProduzioneBatchDetailView: View {
    @Bindable var batch: ProduzioneBatch
    let user: LocalUser
    let onUpdated: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ProduzioneBatchLiveCaptureView(
                batch: batch,
                user: user,
                onUpdated: onUpdated,
                onCompleted: { dismiss() }
            )
            .navigationTitle("Lotto \(batch.batchCode)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}
